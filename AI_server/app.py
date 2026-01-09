import io
import torch
from fastapi import FastAPI, UploadFile, File
from PIL import Image
from torchvision import transforms
from trash_detect import *

# Init app
app = FastAPI()

# Init model ai
trash_detector = TrashDetector()

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    # Đọc file ảnh từ request
    request_object_content = await file.read()
    pil_image = Image.open(io.BytesIO(request_object_content)).convert("RGB")
    
    confidence, predicted_label = trash_detector.detect(image=pil_image)

    # Trả về kết quả JSON
    return {
        "label": f"Loại rác {predicted_label}", # Bạn hãy map với tên thật của rác
        "confidence": round(confidence, 4)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)