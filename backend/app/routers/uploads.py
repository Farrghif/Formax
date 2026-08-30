import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from .. import models
from ..deps import get_optional_user, get_respondent_key

router = APIRouter(prefix="/uploads", tags=["uploads"])

UPLOAD_DIR = "static/uploads"
BASE_URL = os.getenv("BASE_URL", "http://localhost:8000").strip().rstrip("/")

# FIX Bug: batchasi tipe file supaya tidak bisa upload HTML/JS (stored XSS kalau
# diserve static) atau file raksasa yang memenuhi disk.
ALLOWED_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".webp", ".pdf",
    ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".zip",
}
MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10 MB


@router.post("")
async def upload_file(
    file: UploadFile = File(...),
    current_user: Optional[models.User] = Depends(get_optional_user),
    respondent_key: Optional[str] = Depends(get_respondent_key),
):
    """
    Dipakai buat field tipe file_upload. Client upload file ke sini DULU,
    dapat balik file_url, baru URL itu yang dikirim ke PUT /submissions/{id}/answers.

    Identitas boleh login (Bearer) ATAU anonim (X-Respondent-Key) — mirip alur isi form.
    """
    if current_user is None and not respondent_key:
        raise HTTPException(status_code=401, detail="Identitas diperlukan untuk upload file")

    ext = (os.path.splitext(file.filename or "")[1] or "").lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Tipe file '{ext or '(tanpa ekstensi)'}' tidak diizinkan")

    content = await file.read()
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail="Ukuran file melebihi batas 10 MB")

    os.makedirs(UPLOAD_DIR, exist_ok=True)
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as f:
        f.write(content)

    return {"file_url": f"{BASE_URL}/static/uploads/{filename}"}
