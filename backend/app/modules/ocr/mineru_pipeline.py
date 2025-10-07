"""
使用 MinerU Python API 的直接集成
比 CLI 更可靠、更快速
"""

import json
import shutil
from pathlib import Path
from typing import Dict, Optional
from loguru import logger

try:
    from mineru import MinerU
    from mineru.models import PipelineBackend
    MINERU_AVAILABLE = True
except ImportError as e:
    MINERU_AVAILABLE = False
    logger.error(f"MinerU 导入失败: {e}")


class MinerUPipeline:
    """
    使用 MinerU Python API 的 OCR 管道
    """
    
    def __init__(self, device: str = "auto", language: str = "en"):
        self.device = device
        self.language = language
        self.mineru = None
        
        if not MINERU_AVAILABLE:
            raise RuntimeError("MinerU 不可用，请安装: pip install -U mineru[core]")
        
        self._initialize_mineru()
    
    def _initialize_mineru(self):
        """初始化 MinerU 实例"""
        try:
            # 使用 pipeline backend 获得最佳质量
            self.mineru = MinerU(
                backend=PipelineBackend(),
                device=self.device,
                language=self.language
            )
            logger.info(f"✅ MinerU 初始化成功 (设备: {self.device}, 语言: {self.language})")
        except Exception as e:
            logger.error(f"❌ MinerU 初始化失败: {e}")
            raise
    
    async def process(self, pdf_path: Path, output_dir: Path) -> Dict:
        """
        处理 PDF 文件并生成 Markdown
        """
        logger.info(f"开始处理: {pdf_path.name}")
        
        try:
            # 确保输出目录存在
            output_dir.mkdir(exist_ok=True, parents=True)
            
            # 使用 MinerU 处理 PDF
            result = await self.mineru.process_pdf(
                pdf_path=str(pdf_path),
                output_dir=str(output_dir),
                table_mode="screenshot",  # 表格截图模式
                formula_mode=True,        # 启用公式识别
                merge_text=True,          # 智能文本合并
                sort_blocks=True          # 块排序
            )
            
            # 整理输出文件
            final_output = self._organize_output(pdf_path, output_dir)
            
            # 读取生成的 Markdown
            markdown = final_output['md_file'].read_text(encoding='utf-8')
            
            # 提取统计信息
            stats = self._extract_stats(final_output['content_list'])
            
            logger.info("✅ PDF 处理完成！")
            
            return {
                'markdown': markdown,
                'output_dir': str(output_dir),
                'stats': stats,
                'processing_time': result.get('processing_time', 0)
            }
            
        except Exception as e:
            logger.error(f"❌ PDF 处理失败: {e}")
            raise
    
    def _organize_output(self, pdf_path: Path, output_dir: Path) -> Dict:
        """
        整理 MinerU 的输出文件
        """
        pdf_name = pdf_path.stem
        
        # MinerU 的输出结构
        md_file = output_dir / f"{pdf_name}.md"
        content_list_file = output_dir / f"{pdf_name}_content_list.json"
        images_dir = output_dir / "images"
        
        if not md_file.exists():
            raise Exception(f"Markdown 文件未生成: {md_file}")
        
        # 重命名输出文件为统一的 output.md
        final_md = output_dir / "output.md"
        final_images = output_dir / "images"
        
        # 移动 Markdown 文件
        if md_file != final_md:
            shutil.move(md_file, final_md)
        
        # 确保图片目录存在
        if images_dir.exists() and images_dir != final_images:
            if final_images.exists():
                shutil.rmtree(final_images)
            shutil.move(images_dir, final_images)
        
        # 读取 content_list
        content_list = {}
        if content_list_file.exists():
            with open(content_list_file, 'r', encoding='utf-8') as f:
                content_list = json.load(f)
        
        return {
            'md_file': final_md,
            'images_dir': final_images,
            'content_list': content_list
        }
    
    def _extract_stats(self, content_list: Dict) -> Dict:
        """
        从 content_list.json 提取统计信息
        """
        stats = {
            'total_pages': 0,
            'total_elements': 0,
            'tables': 0,
            'figures': 0,
            'formulas': 0
        }
        
        if not content_list:
            return stats
        
        # content_list 是列表，每个元素是一页
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
        
        return stats
