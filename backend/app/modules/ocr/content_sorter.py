from typing import List, Dict
from loguru import logger


class ContentSorter:
    """
    参考 MinerU 的内容排序逻辑
    保持学术论文的阅读顺序（从左到右，从上到下）
    """

    def __init__(self, y_tolerance: int = 20):
        """
        y_tolerance: Y坐标容差，用于判断是否在同一行
        """
        self.y_tolerance = y_tolerance

    def sort_reading_order(self, elements: List[Dict]) -> List[Dict]:
        """
        对所有元素按阅读顺序排序
        """
        logger.info("开始内容排序...")

        if not elements:
            return []

        # 1. 先按Y坐标排序（从上到下）
        sorted_by_y = sorted(elements, key=lambda e: e['bbox'][1])

        # 2. 分组同一行的元素
        lines = self._group_by_lines(sorted_by_y)

        # 3. 每行内按X坐标排序（从左到右）
        sorted_elements = []
        for line in lines:
            sorted_line = sorted(line, key=lambda e: e['bbox'][0])
            sorted_elements.extend(sorted_line)

        logger.info(f"  排序完成，共 {len(sorted_elements)} 个元素")
        return sorted_elements

    def _group_by_lines(self, elements: List[Dict]) -> List[List[Dict]]:
        """
        将Y坐标相近的元素分组到同一行
        """
        if not elements:
            return []

        lines = []
        current_line = [elements[0]]
        current_y = elements[0]['bbox'][1]

        for elem in elements[1:]:
            elem_y = elem['bbox'][1]

            # 如果Y坐标相差在容差范围内，归为同一行
            if abs(elem_y - current_y) <= self.y_tolerance:
                current_line.append(elem)
            else:
                # 否则开始新的一行
                lines.append(current_line)
                current_line = [elem]
                current_y = elem_y

        # 添加最后一行
        if current_line:
            lines.append(current_line)

        return lines

    def merge_text_blocks(self, text_blocks: List[Dict]) -> List[Dict]:
        """
        合并相邻的文本块（同一段落）
        """
        if not text_blocks:
            return []

        merged = []
        current_paragraph = text_blocks[0]['text']
        current_bbox = text_blocks[0]['bbox']

        for i in range(1, len(text_blocks)):
            block = text_blocks[i]
            prev_block = text_blocks[i - 1]

            # 判断是否应该合并（Y坐标接近，说明在同一段）
            if self._should_merge(prev_block, block):
                current_paragraph += " " + block['text']
                # 更新bbox
                current_bbox = self._merge_bbox(current_bbox, block['bbox'])
            else:
                # 保存当前段落，开始新段落
                merged.append({
                    'type': 'text',
                    'content': current_paragraph,
                    'bbox': current_bbox
                })
                current_paragraph = block['text']
                current_bbox = block['bbox']

        # 添加最后一个段落
        merged.append({
            'type': 'text',
            'content': current_paragraph,
            'bbox': current_bbox
        })

        return merged

    def _should_merge(self, block1: Dict, block2: Dict) -> bool:
        """判断两个文本块是否应该合并"""
        y1 = block1['bbox'][1]
        y2 = block2['bbox'][1]

        # Y坐标相差小于容差，认为是同一段
        return abs(y2 - y1) <= self.y_tolerance

    def _merge_bbox(self, bbox1: List, bbox2: List) -> List:
        """合并两个bbox"""
        return [
            min(bbox1[0], bbox2[0]),  # x1
            min(bbox1[1], bbox2[1]),  # y1
            max(bbox1[2], bbox2[2]),  # x2
            max(bbox1[3], bbox2[3])  # y2
        ]