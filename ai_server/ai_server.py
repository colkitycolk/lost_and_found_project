from fastapi import FastAPI, UploadFile, File, HTTPException
from sentence_transformers import SentenceTransformer
from pydantic import BaseModel
from PIL import Image
import io
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="CLIP AI Server")

# Load model once on startup
try:
    logger.info("Loading CLIP model (clip-ViT-B-32)...")
    model = SentenceTransformer('clip-ViT-B-32')
    logger.info("Model loaded successfully (512 dimensions).")
except Exception as e:
    logger.error(f"Critical error loading model: {e}")

class TextRequest(BaseModel):
    text: str

@app.get("/")
async def health():
    return {"status": "ready", "dimensions": 512}

@app.post("/embed")
async def embed_text(data: TextRequest):
    try:
        # CLIP text encoding
        vector = model.encode(data.text).tolist()
        return {"embedding": vector}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/embed-image")
async def embed_image(file: UploadFile = File(...)):
    try:
        # Validate it's an image
        if not file.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="Invalid file type")

        # Read into memory
        img_bytes = await file.read()
        image = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        
        # Generate image embedding
        vector = model.encode(image).tolist()
        
        logger.info(f"Image processed: {file.filename}")
        return {"embedding": vector}
    except Exception as e:
        logger.error(f"Image Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))