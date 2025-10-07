from PIL import Image
import numpy as np
from typing import List, Dict
from loguru import logger
from app.core.model_manager import model_manager


class TextOCR:
    def __init__(self, model_size: str = "small"):
        self.ocr = model_manager.get_ocr_model(model_size)

    def extract_text(self, image: Image.Image, regions: List[Dict] = None) -> List[Dict]:
        """
        使用 PaddleOCR 提取文本
        如果提供 regions，则只在指定区域内提取
        """
        logger.info("执行文本OCR...")

        img_array = np.array(image)
        result = self.ocr.ocr(img_array, cls=False)

        # 解析OCR结果
        text_blocks = []
        if result and result[0]:
            for line in result[0]:
                bbox = line[0]  # [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
                text = line[1][0]
                conf = line[1][1]

                # 转换bbox为 [x1, y1, x2, y2]
                x_coords = [p[0] for p in bbox]
                y_coords = [p[1] for p in bbox]

                text_blocks.append({
                    'text': text,
                    'bbox': [min(x_coords), min(y_coords), max(x_coords), max(y_coords)],
                    'confidence': conf
                })

        logger.info(f"  提取到 {len(text_blocks)} 个文本块")
        return text_blocks