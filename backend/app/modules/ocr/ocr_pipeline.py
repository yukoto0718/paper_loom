# backend/app/modules/ocr/ocr_pipeline.py

import subprocess
import json
import shutil
import sys
import asyncio
from pathlib import Path
from typing import Dict
from loguru import logger

try:
    import torch
    CUDA_AVAILABLE = torch.cuda.is_available()
except ImportError:
    CUDA_AVAILABLE = False

class OCRPipeline:
    """
    使用 MinerU 的简化流程
    所有复杂逻辑（文本合并、排序、图片定位）由 MinerU 处理
    """
    
    def __init__(self, ocr_model_size: str = "small"):
        self.ocr_model_size = ocr_model_size
        self.device = "cuda" if CUDA_AVAILABLE else "cpu"
        self.mineru_available = self._check_mineru_available()
    
    def _check_mineru_available(self):
        """检查 MinerU 是否可用"""
        try:
            # 检查 CLI 是否可用
            result = subprocess.run(
                ["mineru", "--version"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                logger.info(f"✅ MinerU CLI 可用: {result.stdout.strip()} (设备: {self.device})")
                return True
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
        
        logger.error("❌ MinerU 不可用，请安装: pip install -U mineru[core]")
        return False
    
    async def process(self, pdf_path: Path, output_dir: Path) -> Dict:
        """
        完整处理流程 - 使用异步执行避免阻塞
        """
        logger.info(f"开始处理: {pdf_path.name} (设备: {self.device})")
        
        if not self.mineru_available:
            # 如果 MinerU 不可用，使用备用方案
            return await self._use_fallback(pdf_path, output_dir)
        
        # 创建临时输出目录（MinerU 会在这里生成文件）
        temp_output = output_dir / "mineru_temp"
        temp_output.mkdir(exist_ok=True, parents=True)
        
        try:
            # 1. 异步调用 MinerU 处理
            await self._run_mineru_async(pdf_path, temp_output)
            
            # 2. 整理输出文件
            final_output = self._organize_output(
                pdf_path,
                temp_output,
                output_dir
            )
            
            # 3. 读取 Markdown
            markdown = final_output['md_file'].read_text(encoding='utf-8')
            
            # 4. 提取统计信息
            stats = self._extract_stats(
                final_output['content_list'],
                output_dir=output_dir,
                markdown_content=markdown
            )
            
            logger.info("✅ MinerU 处理完成！")
            
            return {
                'markdown': markdown,
                'output_dir': str(output_dir),
                'stats': stats,
                'mineru_success': True
            }
        
        except Exception as e:
            logger.warning(f"MinerU 处理失败，使用备用方案: {e}")
            # 清理临时文件
            if temp_output.exists():
                shutil.rmtree(temp_output)
            # 使用备用方案
            return await self._use_fallback(pdf_path, output_dir)
    
    async def _run_mineru_async(self, pdf_path: Path, output_dir: Path):
        """
        调用 MinerU CLI - Windows兼容版本
        """
        logger.info("调用 MinerU...")
        
        # 构建命令 - 使用GPU加速
        cmd = [
            "mineru",
            "-p", str(pdf_path),
            "-o", str(output_dir),
            
            # ✅ 关键配置
            "-b", "pipeline",           # 使用 pipeline backend
            "--lang", "en",             # 英文OCR
            "-t", "false",              # ❗表格截图模式（不识别）
            "-f", "true",               # 公式识别
            "-d", "cuda",               # 🚀 使用GPU加速 (你的RTX 4060)
        ]
        
        logger.info(f"执行命令: {' '.join(cmd)}")
        
        # Windows兼容的异步执行
        try:
            # 使用线程池执行同步subprocess
            import concurrent.futures
            loop = asyncio.get_event_loop()
            
            def run_mineru_sync():
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=300,  # 5分钟超时
                    shell=True    # Windows需要shell=True
                )
                return result
            
            # 在线程池中运行
            with concurrent.futures.ThreadPoolExecutor() as pool:
                result = await loop.run_in_executor(pool, run_mineru_sync)
            
            if result.returncode != 0:
                error_msg = result.stderr if result.stderr else result.stdout
                logger.error(f"MinerU 处理失败: {error_msg}")
                raise Exception(f"MinerU 处理失败: {error_msg}")
            
            logger.info("✅ MinerU 处理完成")
            
        except subprocess.TimeoutExpired:
            logger.error("❌ MinerU 处理超时 (5分钟)")
            raise Exception("MinerU 处理超时，请检查PDF文件或重试")
        except Exception as e:
            logger.error(f"MinerU 执行错误: {e}")
            raise
    
    async def _use_fallback(self, pdf_path: Path, output_dir: Path) -> Dict:
        """
        使用备用方案处理PDF
        """
        try:
            from .fallback_pipeline import FallbackPipeline
            fallback = FallbackPipeline()
            result = await fallback.process(pdf_path, output_dir)
            result['fallback_used'] = True
            return result
        except Exception as e:
            logger.error(f"备用方案也失败: {e}")
            raise Exception(f"所有处理方案都失败: {e}")
    
    def _organize_output(
        self,
        pdf_path: Path,
        temp_output: Path,
        final_output: Path
    ) -> Dict:
        """
        整理 MinerU 的输出文件
        
        MinerU 输出结构可能不同，需要灵活处理
        """
        pdf_name = pdf_path.stem
        
        # 查找可能的输出目录结构
        possible_dirs = [
            temp_output / "auto",
            temp_output / pdf_name / "auto",
            temp_output
        ]
        
        auto_dir = None
        for possible_dir in possible_dirs:
            if possible_dir.exists():
                auto_dir = possible_dir
                logger.info(f"找到 MinerU 输出目录: {auto_dir}")
                break
        
        if not auto_dir:
            # 检查是否有直接的文件
            md_files = list(temp_output.rglob("*.md"))
            if md_files:
                auto_dir = temp_output
                logger.info(f"使用根目录作为输出目录，找到 {len(md_files)} 个MD文件")
            else:
                raise Exception(f"MinerU 输出目录不存在，检查: {temp_output}")
        
        # 查找 Markdown 文件
        md_files = list(auto_dir.rglob("*.md"))
        if not md_files:
            raise Exception(f"在 {auto_dir} 中未找到 Markdown 文件")
        
        md_file = md_files[0]  # 使用第一个找到的MD文件
        logger.info(f"找到 Markdown 文件: {md_file}")
        
        # 查找 content_list 文件
        content_list_files = list(auto_dir.rglob("*content_list.json"))
        content_list_file = content_list_files[0] if content_list_files else None
        
        # 查找图片目录
        images_dirs = list(auto_dir.rglob("images"))
        images_dir = images_dirs[0] if images_dirs else None
        
        # 移动文件到最终输出目录
        final_md = final_output / "output.md"
        final_images = final_output / "images"
        
        # 复制 Markdown (处理编码问题)
        try:
            # 尝试UTF-8编码
            content = md_file.read_text(encoding='utf-8')
            final_md.write_text(content, encoding='utf-8')
        except UnicodeDecodeError:
            # 如果UTF-8失败，尝试其他编码
            try:
                content = md_file.read_text(encoding='cp932')
                final_md.write_text(content, encoding='utf-8')
            except UnicodeDecodeError:
                # 最后尝试latin-1
                content = md_file.read_text(encoding='latin-1')
                final_md.write_text(content, encoding='utf-8')
        
        # 复制图片目录
        if images_dir and images_dir.exists():
            if final_images.exists():
                shutil.rmtree(final_images)
            shutil.copytree(images_dir, final_images)
        
        # 读取 content_list
        content_list = {}
        if content_list_file and content_list_file.exists():
            try:
                with open(content_list_file, 'r', encoding='utf-8') as f:
                    content_list = json.load(f)
            except UnicodeDecodeError:
                try:
                    with open(content_list_file, 'r', encoding='cp932') as f:
                        content_list = json.load(f)
                except UnicodeDecodeError:
                    with open(content_list_file, 'r', encoding='latin-1') as f:
                        content_list = json.load(f)
        
        return {
            'md_file': final_md,
            'images_dir': final_images,
            'content_list': content_list
        }
    
    def _extract_stats(self, content_list: Dict, output_dir: Path = None, markdown_content: str = None) -> Dict:
        """
        提取统计信息 - 从content_list或实际文件统计
        """
        stats = {
            'total_pages': 0,
            'total_elements': 0,
            'tables': 0,
            'figures': 0,
            'formulas': 0,
            'total_images': 0
        }
        
        # 如果content_list存在，使用它统计
        if content_list and isinstance(content_list, list):
            for page in content_list:
                stats['total_pages'] += 1
                
                # 统计各类元素
                for block in page.get('preproc_blocks', []):
                    stats['total_elements'] += 1
                    
                    block_type = block.get('type', '')
                    if block_type == 'table':
                        stats['tables'] += 1
                    elif block_type == 'image':
                        stats['figures'] += 1
                    elif block_type in ['equation', 'inline_equation']:
                        stats['formulas'] += 1
        
        # 如果content_list不存在或统计为0，使用实际文件统计
        if stats['figures'] == 0 and output_dir:
            # 统计实际图片文件
            images_dir = output_dir / "images"
            if images_dir.exists():
                image_files = list(images_dir.rglob("*.png")) + list(images_dir.rglob("*.jpg")) + list(images_dir.rglob("*.jpeg"))
                stats['figures'] = len(image_files)
                stats['total_images'] = len(image_files)
        
        # 从markdown内容统计表格和图片引用
        if markdown_content:
            # 统计markdown中的图片引用
            md_images = markdown_content.count('![')
            if md_images > stats['figures']:
                stats['figures'] = md_images
            
            # 统计markdown中的表格（简单的表格检测）
            tables = markdown_content.count('|--') + markdown_content.count('|---')
            if tables > stats['tables']:
                stats['tables'] = tables
            
            # 统计公式（LaTeX格式）
            formulas = markdown_content.count('$$') // 2 + markdown_content.count('$') // 2
            if formulas > stats['formulas']:
                stats['formulas'] = formulas
        
        # 确保至少有一些基本统计
        if stats['total_pages'] == 0 and markdown_content:
            # 从markdown内容估算页数（每页约500-1000字符）
            char_count = len(markdown_content)
            stats['total_pages'] = max(1, char_count // 800)
        
        return stats
