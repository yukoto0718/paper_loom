"""
PDF处理模块 - 备用方案
当magic-pdf无法正常工作时，使用其他方法处理PDF
"""

from pathlib import Path
from typing import Dict, Optional
from loguru import logger
import subprocess
import shutil
import json


class PDFProcessor:
    """PDF处理器 - 提供多种处理方案"""
    
    def __init__(self):
        self.supported_methods = ["magic-pdf", "pymupdf", "pdfplumber"]
    
    async def process_pdf(self, pdf_path: Path, output_dir: Path, method: str = "auto") -> Dict:
        """
        处理PDF文件，尝试多种方法
        """
        logger.info(f"开始处理PDF: {pdf_path.name}")
        
        # 确保输出目录存在
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # 根据方法选择处理方式
        if method == "auto":
            # 自动选择最佳方法
            result = await self._try_methods(pdf_path, output_dir)
        elif method == "magic-pdf":
            result = await self._process_with_magic_pdf(pdf_path, output_dir)
        elif method == "pymupdf":
            result = await self._process_with_pymupdf(pdf_path, output_dir)
        elif method == "pdfplumber":
            result = await self._process_with_pdfplumber(pdf_path, output_dir)
        else:
            raise ValueError(f"不支持的处理方法: {method}")
        
        return result
    
    async def _try_methods(self, pdf_path: Path, output_dir: Path) -> Dict:
        """尝试多种处理方法"""
        methods = ["magic-pdf", "pymupdf", "pdfplumber"]
        
        for method in methods:
            try:
                logger.info(f"尝试使用方法: {method}")
                if method == "magic-pdf":
                    result = await self._process_with_magic_pdf(pdf_path, output_dir / f"temp_{method}")
                elif method == "pymupdf":
                    result = await self._process_with_pymupdf(pdf_path, output_dir)
                elif method == "pdfplumber":
                    result = await self._process_with_pdfplumber(pdf_path, output_dir / f"temp_{method}")
                
                # 如果成功，清理临时目录并返回结果
                for temp_dir in output_dir.glob("temp_*"):
                    shutil.rmtree(temp_dir, ignore_errors=True)
                
                logger.info(f"✅ 使用方法 {method} 处理成功")
                return result
                
            except Exception as e:
                logger.warning(f"方法 {method} 失败: {e}")
                continue
        
        # 所有方法都失败
        raise RuntimeError("所有PDF处理方法都失败了")
    
    async def _process_with_magic_pdf(self, pdf_path: Path, output_dir: Path) -> Dict:
        """使用magic-pdf处理PDF"""
        try:
            # 构建命令
            cmd = [
                "magic-pdf",
                "-p", str(pdf_path),
                "-o", str(output_dir),
                "-m", "auto"
            ]
            
            logger.info(f"执行: {' '.join(cmd)}")
            
            # 执行 - 修复编码问题
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='ignore',
                timeout=600
            )
            
            logger.info(f"返回码: {result.returncode}")
            
            # 检查输出文件
            md_files = list(output_dir.rglob("*.md"))
            json_files = list(output_dir.rglob("content_list.json"))
            
            if md_files:
                md_file = md_files[0]
                md_content = md_file.read_text(encoding='utf-8')
                
                # 复制到最终输出
                final_md = output_dir.parent / "output.md"
                shutil.copy(md_file, final_md)
                
                # 复制图片
                images_src = md_file.parent / "images"
                images_dst = output_dir.parent / "images"
                if images_src.exists():
                    if images_dst.exists():
                        shutil.rmtree(images_dst)
                    shutil.copytree(images_src, images_dst)
                
                stats = self._calculate_stats(md_content, images_dst)
                
                return {
                    'markdown': md_content,
                    'output_dir': str(output_dir.parent),
                    'stats': stats,
                    'method': 'magic-pdf'
                }
            elif json_files:
                # 处理JSON文件
                json_file = json_files[0]
                md_content = self._json_to_markdown(json_file)
                
                final_md = output_dir.parent / "output.md"
                final_md.write_text(md_content, encoding='utf-8')
                
                # 复制图片
                images_src = json_file.parent / "images"
                images_dst = output_dir.parent / "images"
                if images_src.exists():
                    if images_dst.exists():
                        shutil.rmtree(images_dst)
                    shutil.copytree(images_src, images_dst)
                
                stats = self._calculate_stats(md_content, images_dst)
                
                return {
                    'markdown': md_content,
                    'output_dir': str(output_dir.parent),
                    'stats': stats,
                    'method': 'magic-pdf'
                }
            else:
                raise RuntimeError("magic-pdf未生成任何输出文件")
                
        except Exception as e:
            logger.error(f"magic-pdf处理失败: {e}")
            raise
    
    async def _process_with_pymupdf(self, pdf_path: Path, output_dir: Path) -> Dict:
        """使用PyMuPDF处理PDF（备用方案）"""
        try:
            import fitz  # PyMuPDF
            
            logger.info("使用PyMuPDF处理PDF...")
            
            # 打开PDF
            doc = fitz.open(str(pdf_path))
            
            # 创建图片目录
            images_dir = output_dir / "images"
            images_dir.mkdir(exist_ok=True)
            
            # 提取文本和图片
            text_content = ""
            image_count = 0
            table_count = 0
            
            for page_num in range(len(doc)):
                page = doc[page_num]
                text_content += f"# 第 {page_num + 1} 页\n\n"
                
                # 提取文本
                page_text = page.get_text()
                text_content += page_text
                
                # 提取图片
                image_list = page.get_images()
                for img_index, img in enumerate(image_list):
                    try:
                        # 获取图片
                        xref = img[0]
                        pix = fitz.Pixmap(doc, xref)
                        
                        if pix.n - pix.alpha < 4:  # 检查是否为RGB或灰度图
                            # 保存图片
                            img_filename = f"page_{page_num+1}_img_{img_index+1}.png"
                            img_path = images_dir / img_filename
                            
                            # 保存图片
                            pix.save(str(img_path))
                            
                            # 在文本中标记图片位置
                            text_content += f"\n\n![图片](images/{img_filename})\n\n"
                            image_count += 1
                        
                        pix = None  # 释放内存
                    except Exception as img_e:
                        logger.warning(f"提取图片失败: {img_e}")
                        continue
                
                # 检测表格（通过文本模式识别）
                if "Table" in page_text or "表" in page_text:
                    table_count += 1
                    text_content += f"\n\n[表格 {table_count}]\n\n"
                
                text_content += "\n\n---\n\n"
            
            doc.close()
            
            # 保存Markdown
            md_file = output_dir / "output.md"
            md_file.write_text(text_content, encoding='utf-8')
            
            stats = self._calculate_stats(text_content, images_dir)
            
            # 更新统计信息
            stats['figures'] = image_count
            stats['tables'] = table_count
            
            return {
                'markdown': text_content,
                'output_dir': str(output_dir),
                'stats': stats,
                'method': 'pymupdf'
            }
            
        except ImportError:
            raise RuntimeError("PyMuPDF未安装，请运行: pip install PyMuPDF")
        except Exception as e:
            logger.error(f"PyMuPDF处理失败: {e}")
            raise
    
    async def _process_with_pdfplumber(self, pdf_path: Path, output_dir: Path) -> Dict:
        """使用pdfplumber处理PDF（备用方案）"""
        try:
            import pdfplumber
            
            logger.info("使用pdfplumber处理PDF...")
            
            # 打开PDF
            text_content = ""
            with pdfplumber.open(str(pdf_path)) as pdf:
                for page_num, page in enumerate(pdf.pages):
                    text_content += f"# 第 {page_num + 1} 页\n\n"
                    text_content += page.extract_text() or ""
                    text_content += "\n\n---\n\n"
            
            # 保存Markdown
            md_file = output_dir.parent / "output.md"
            md_file.write_text(text_content, encoding='utf-8')
            
            # 创建图片目录
            images_dir = output_dir.parent / "images"
            images_dir.mkdir(exist_ok=True)
            
            stats = self._calculate_stats(text_content, images_dir)
            
            return {
                'markdown': text_content,
                'output_dir': str(output_dir.parent),
                'stats': stats,
                'method': 'pdfplumber'
            }
            
        except ImportError:
            raise RuntimeError("pdfplumber未安装，请运行: pip install pdfplumber")
        except Exception as e:
            logger.error(f"pdfplumber处理失败: {e}")
            raise
    
    def _json_to_markdown(self, json_file: Path) -> str:
        """从content_list.json转换为Markdown"""
        try:
            data = json.loads(json_file.read_text(encoding='utf-8'))
            
            md_lines = []
            
            for page in data:
                for block in page.get('preproc_blocks', []):
                    block_type = block.get('type', '')
                    
                    if block_type == 'text':
                        md_lines.append(block.get('text', ''))
                    elif block_type == 'image':
                        img_path = block.get('img_path', '')
                        md_lines.append(f"![Image]({img_path})")
                    elif block_type == 'table':
                        img_path = block.get('img_path', '')
                        md_lines.append(f"![Table]({img_path})")
                
                md_lines.append("\n---\n")
            
            return "\n\n".join(md_lines)
            
        except Exception as e:
            logger.error(f"JSON转换失败: {e}")
            return "# 转换失败\n\n处理过程中出现错误。"
    
    def _calculate_stats(self, md_content: str, images_dir: Path) -> Dict:
        """计算统计信息"""
        return {
            'total_pages': md_content.count('---') + 1,
            'tables': md_content.count('![Table') + md_content.count('![table'),
            'figures': md_content.count('![Figure') + md_content.count('![Image'),
            'formulas': md_content.count('$$'),
            'total_images': len(list(images_dir.glob('*.*'))) if images_dir.exists() else 0
        }
