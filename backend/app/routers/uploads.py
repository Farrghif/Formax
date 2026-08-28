import os
import uuid

from fastapi import APIRouter, Depends, UploadFile, File

from .. import models
from ..deps import get_current_user

router = APIRouter(prefix="/uploads", tags=["uploads"])

UPLOAD_DIR = "static/uploads"
BASE_URL = os.getenv("BASE_URL", "http://localhost:8000").strip().rstrip("/")


@router.post("")
async def upload_file(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
):
    """
    Dipakai buat field tipe file_upload. Client upload file ke sini DULU,
    dapat balik file_url, baru URL itu yang dikirim ke PUT /submissions/{id}/answers.
    """
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    ext = os.path.splitext(file.filename)[1]
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as f:
        content = await file.read()
        f.write(content)

    return {"file_url": f"{BASE_URL}/static/uploads/{filename}"}
