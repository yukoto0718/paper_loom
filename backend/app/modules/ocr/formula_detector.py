from PIL import Image
from typing import List, Dict
from loguru import logger
from app.core.model_manager import model_manager


class FormulaDetector:
    def __init__(self):
        self.model = model_manager.get_formula_detector()

    def detect(self, image: Image.Image) -> List[Dict]:
        """
        使用 YOLOv8 检测公式区域
        """
        logger.info("执行公式检测...")

        results = self.model(image, conf=0.5)

        formulas = []
        for result in results[0].boxes:
            bbox = result.xyxy[0].cpu().numpy()
            formulas.append({
                'bbox': bbox.tolist(),  # [x1, y1, x2, y2]
                'confidence': float(result.conf)
            })

        logger.info(f"  检测到 {len(formulas)} 个公式")
        return formulas