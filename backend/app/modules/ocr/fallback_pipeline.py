"""
Fallback PDF processing when MinerU fails
Provides basic text extraction as backup
"""

import json
import shutil
from pathlib import Path
from typing import Dict
from loguru import logger

# 支持 PyPDF2 和 pypdf（PyPDF2 的现代替代品）
try:
    import PyPDF2
    PYPDF2_AVAILABLE = True
except ImportError:
    PYPDF2_AVAILABLE = False

try:
    import pypdf
    PYPDF_AVAILABLE = True
except ImportError:
    PYPDF_AVAILABLE = False


class FallbackPipeline:
    """
    Basic PDF text extraction as fallback when MinerU fails
    """
    
    def __init__(self):
        if not PYPDF2_AVAILABLE and not PYPDF_AVAILABLE:
            raise RuntimeError("PyPDF2 or pypdf not available for fallback processing")
    
    async def process(self, pdf_path: Path, output_dir: Path) -> Dict:
        """
        Basic PDF text extraction
        """
        logger.warning(f"使用备用方案处理: {pdf_path.name}")
        
        try:
            # Ensure output directory exists
            output_dir.mkdir(exist_ok=True, parents=True)
            
            # Extract text from PDF
            text_content = self._extract_pdf_text(pdf_path)
            
            # Create basic markdown
            markdown = self._create_basic_markdown(pdf_path, text_content)
            
            # Save markdown file
            md_file = output_dir / "output.md"
            md_file.write_text(markdown, encoding='utf-8')
            
            # Generate basic stats
            stats = self._generate_stats(pdf_path, text_content)
            
            logger.info("✅ 备用方案处理完成")
            
            return {
                'markdown': markdown,
                'output_dir': str(output_dir),
                'stats': stats,
                'fallback': True
            }
            
        except Exception as e:
            logger.error(f"备用方案处理失败: {e}")
            raise
    
    def _extract_pdf_text(self, pdf_path: Path) -> str:
        """Extract text from PDF using PyPDF2 or pypdf"""
        try:
            if PYPDF2_AVAILABLE:
                with open(pdf_path, 'rb') as f:
                    pdf_reader = PyPDF2.PdfReader(f)
                    text_content = ""
                    
                    for page_num, page in enumerate(pdf_reader.pages, 1):
                        page_text = page.extract_text()
                        if page_text:
                            text_content += f"--- Page {page_num} ---\n{page_text}\n\n"
                    
                    return text_content
            elif PYPDF_AVAILABLE:
                with open(pdf_path, 'rb') as f:
                    pdf_reader = pypdf.PdfReader(f)
                    text_content = ""
                    
                    for page_num, page in enumerate(pdf_reader.pages, 1):
                        page_text = page.extract_text()
                        if page_text:
                            text_content += f"--- Page {page_num} ---\n{page_text}\n\n"
                    
                    return text_content
            else:
                raise RuntimeError("No PDF library available")
                
        except Exception as e:
            raise Exception(f"PDF文本提取失败: {e}")
    
    def _create_basic_markdown(self, pdf_path: Path, text_content: str) -> str:
        """Create basic markdown from extracted text"""
        pdf_name = pdf_path.stem
        
        markdown = f"""# {pdf_name}

> ⚠️ 注意：这是备用方案生成的Markdown
> MinerU处理失败，使用基本文本提取

## 内容

{text_content}

---
*生成时间: {self._get_current_time()}*
*状态: 备用方案（基本文本提取）*
"""
        return markdown
    
    def _generate_stats(self, pdf_path: Path, text_content: str) -> Dict:
        """Generate basic statistics"""
        page_count = 0
        try:
            if PYPDF2_AVAILABLE:
                with open(pdf_path, 'rb') as f:
                    pdf_reader = PyPDF2.PdfReader(f)
                    page_count = len(pdf_reader.pages)
            elif PYPDF_AVAILABLE:
                with open(pdf_path, 'rb') as f:
                    pdf_reader = pypdf.PdfReader(f)
                    page_count = len(pdf_reader.pages)
        except:
            page_count = 0
        
        word_count = len(text_content.split())
        char_count = len(text_content)
        
        return {
            'total_pages': page_count,
            'total_elements': 0,
            'tables': 0,
            'figures': 0,
            'formulas': 0,
            'word_count': word_count,
            'char_count': char_count,
            'fallback': True
        }
    
    def _get_current_time(self):
        """Get current timestamp"""
        from datetime import datetime
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")
