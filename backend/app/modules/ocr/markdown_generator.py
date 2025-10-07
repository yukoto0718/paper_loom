from pathlib import Path
from typing import List, Dict
from PIL import Image
from loguru import logger


class MarkdownGenerator:
    """
    参考 MinerU 的 Markdown 生成逻辑
    """

    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.images_dir = output_dir / "images"
        self.images_dir.mkdir(exist_ok=True)

        # 计数器
        self.table_counter = 0
        self.figure_counter = 0
        self.formula_counter = 0

    def generate(self, sorted_elements: List[Dict], page_images: List[Image.Image]) -> str:
        """
        生成 Markdown 文件
        """
        logger.info("开始生成Markdown...")

        md_lines = []

        for elem in sorted_elements:
            elem_type = elem['type']

            if elem_type == 'text' or elem_type == 'title':
                # 文本/标题
                text = elem.get('content', '')
                if elem_type == 'title':
                    # 标题加粗
                    md_lines.append(f"**{text}**\n")
                else:
                    md_lines.append(f"{text}\n")

            elif elem_type == 'formula':
                # 公式 (LaTeX格式)
                latex = elem.get('latex', '')
                if latex:
                    # 行间公式
                    md_lines.append(f"$$\n{latex}\n$$\n")
                else:
                    # 识别失败，使用fallback
                    self.formula_counter += 1
                    img_path = self._save_region_image(
                        page_images[elem['page_num']],
                        elem['bbox'],
                        f"formula_{self.formula_counter}.png"
                    )
                    md_lines.append(f"![Formula {self.formula_counter}]({img_path})\n")

            elif elem_type == 'table':
                # 表格截图
                self.table_counter += 1
                img_path = self._save_region_image(
                    page_images[elem['page_num']],
                    elem['bbox'],
                    f"table_{self.table_counter}.png"
                )
                md_lines.append(f"**Table {self.table_counter}**\n")
                md_lines.append(f"![Table {self.table_counter}]({img_path})\n")

            elif elem_type == 'figure':
                # 图片截图
                self.figure_counter += 1
                img_path = self._save_region_image(
                    page_images[elem['page_num']],
                    elem['bbox'],
                    f"figure_{self.figure_counter}.png"
                )
                md_lines.append(f"**Figure {self.figure_counter}**\n")
                md_lines.append(f"![Figure {self.figure_counter}]({img_path})\n")

        markdown_content = "\n".join(md_lines)

        # 保存MD文件
        md_file = self.output_dir / "output.md"
        md_file.write_text(markdown_content, encoding='utf-8')

        logger.info(f"✅ Markdown生成完成: {md_file}")
        logger.info(f"  - 表格: {self.table_counter} 个")
        logger.info(f"  - 图片: {self.figure_counter} 个")
        logger.info(f"  - 公式: {self.formula_counter} 个")

        return markdown_content

    def _save_region_image(self, page_image: Image.Image, bbox: List, filename: str) -> str:
        """
        从页面图片中裁剪区域并保存
        返回相对路径
        """
        x1, y1, x2, y2 = [int(v) for v in bbox]

        # 裁剪
        region = page_image.crop((x1, y1, x2, y2))

        # 保存
        save_path = self.images_dir / filename
        region.save(save_path)

        # 返回相对路径（相对于MD文件）
        return f"images/{filename}"