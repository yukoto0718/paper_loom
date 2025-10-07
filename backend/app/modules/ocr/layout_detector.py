import numpy as np
from PIL import Image
from typing import List, Dict
from loguru import logger
from app.core.model_manager import model_manager


class LayoutDetector:
    def __init__(self):
        self.model = model_manager.get_layout_model()

    def detect(self, image: Image.Image) -> List[Dict]:
        """
        使用 LayoutLMv3_ft 检测布局
        返回格式：
        [
            {
                'type': 'text/title/table/figure/formula',
                'bbox': [x1, y1, x2, y2],
                'confidence': 0.95
            }
        ]
        """
        logger.info("执行布局检测...")

        # 转换为numpy数组
        img_array = np.array(image)

        # 调用模型
        results = self.model.predict(img_array)

        # 解析结果
        regions = []
        for result in results:
            regions.append({
                'type': result['label'],  # text/title/table/figure
                'bbox': result['bbox'],  # [x1, y1, x2, y2]
                'confidence': result['score']
            })

        logger.info(f"  检测到 {len(regions)} 个区域")
        return regions