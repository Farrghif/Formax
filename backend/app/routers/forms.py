import io
import os
import uuid
from typing import List

import qrcode
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..deps import get_db, get_current_user

router = APIRouter(prefix="/forms", tags=["forms"])

BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
QR_DIR = "static/qrcodes"


@router.get("", response_model=List[schemas.FormListOut])
def list_my_forms(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Ini yang dipakai buat halaman 'History' — list form + jumlah submission masing-masing."""
    forms = db.query(models.Form).filter(models.Form.owner_id == current_user.id).all()
    result = []
    for f in forms:
        total = db.query(func.count(models.Submission.id)).filter(models.Submission.form_id == f.id).scalar()
        item = schemas.FormListOut.model_validate(f)
        item.total_submissions = total or 0
        result.append(item)
    return result


@router.post("", response_model=schemas.FormOut)
def create_form(
    payload: schemas.FormCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if db.query(models.Form).filter(models.Form.slug == str(payload.slug)).first():
        raise HTTPException(status_code=400, detail="Slug sudah dipakai, pilih yang lain")

    form = models.Form(
        owner_id=current_user.id,
        template_id=payload.template_id,
        title=payload.title,
        description=payload.description,
        slug=payload.slug,
        start_date=payload.start_date,
        end_date=payload.end_date,
        join_token=security.generate_join_token() if payload.use_join_token else None,
    )
    db.add(form)
    db.flush()

    if payload.template_id:
        # copy questions dari template ke form ini (snapshot, bukan reference)
        template_questions = (
            db.query(models.Question)
            .filter(models.Question.template_id == str(payload.template_id))
            .order_by(models.Question.order_index)
            .all()
        )
        for tq in template_questions:
            new_q = models.Question(
                form_id=form.id, type=tq.type, label=tq.label, placeholder=tq.placeholder,
                is_required=tq.is_required, order_index=tq.order_index, settings=tq.settings,
            )
            db.add(new_q)
            db.flush()
            for opt in tq.options:
                db.add(models.QuestionOption(question_id=new_q.id, label=opt.label, value=opt.value, order_index=opt.order_index))
    else:
        for q in payload.questions:
            new_q = models.Question(
                form_id=form.id, type=q.type, label=q.label, placeholder=q.placeholder,
                is_required=q.is_required, order_index=q.order_index, settings=q.settings,
            )
            db.add(new_q)
            db.flush()
            for opt in q.options:
                db.add(models.QuestionOption(question_id=new_q.id, label=opt.label, value=opt.value, order_index=opt.order_index))

    db.commit()
    db.refresh(form)
    return form


@router.get("/{form_id}", response_model=schemas.FormOut)
def get_form_for_owner(form_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")
    return form


@router.patch("/{form_id}", response_model=schemas.FormOut)
def update_form(
    form_id: str, payload: schemas.FormUpdate,
    db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user),
):
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    for key, value in payload.dict(exclude_unset=True).items():
        setattr(form, key, value)
    db.commit()
    db.refresh(form)
    return form


@router.delete("/{form_id}")
def delete_form(form_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")
    db.delete(form)
    db.commit()
    return {"message": "Form dihapus"}


@router.post("/{form_id}/generate-qr")
def generate_qr(form_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Generate QR code dari link publik form, simpan sebagai file static, update qr_code_url."""
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    public_url = f"{BASE_URL}/f/{form.slug}"
    img = qrcode.make(public_url)

    os.makedirs(QR_DIR, exist_ok=True)
    filepath = f"{QR_DIR}/{form.slug}.png"
    img.save(filepath)

    form.qr_code_url = f"{BASE_URL}/static/qrcodes/{form.slug}.png"
    db.commit()
    return {"qr_code_url": form.qr_code_url, "share_link": public_url}


@router.get("/public/{slug}", response_model=schemas.FormOut)
def get_form_by_slug(slug: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """
    Dipanggil pas orang buka link form. TETAP wajib login (sesuai requirement kelompok kamu),
    tapi belum bikin submission — cuma buat nampilin pertanyaan form-nya.
    """
    form = db.query(models.Form).filter(models.Form.slug == slug).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.status != models.FormStatus.published:
        raise HTTPException(status_code=403, detail="Form ini belum/tidak lagi menerima jawaban")
    return form
