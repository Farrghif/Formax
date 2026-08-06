from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from .. import models, schemas
from ..deps import get_db, get_current_user

router = APIRouter(prefix="/templates", tags=["templates"])


@router.get("", response_model=List[schemas.TemplateOut])
def list_templates(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Nampilin template sistem (Blank/Attendance/Exam) + 'My Template' milik user."""
    return (
        db.query(models.Template)
        .filter(or_(models.Template.is_system == True, models.Template.owner_id == current_user.id))
        .all()
    )


@router.get("/mine", response_model=List[schemas.TemplateOut])
def list_my_templates(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Khusus 'My Template' — template buatan sendiri aja."""
    return db.query(models.Template).filter(models.Template.owner_id == current_user.id).all()


@router.post("", response_model=schemas.TemplateOut)
def create_template(
    payload: schemas.TemplateCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    template = models.Template(owner_id=current_user.id, title=payload.title, description=payload.description)
    db.add(template)
    db.flush()

    for q in payload.questions:
        question = models.Question(
            template_id=template.id,
            type=q.type, label=q.label, placeholder=q.placeholder,
            is_required=q.is_required, order_index=q.order_index, settings=q.settings,
        )
        db.add(question)
        db.flush()
        for opt in q.options:
            db.add(models.QuestionOption(question_id=question.id, label=opt.label, value=opt.value, order_index=opt.order_index))

    db.commit()
    db.refresh(template)
    return template


@router.get("/{template_id}", response_model=schemas.TemplateOut)
def get_template(template_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    template = db.query(models.Template).filter(models.Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan")
    if not template.is_system and template.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan template milikmu")
    return template


@router.patch("/{template_id}", response_model=schemas.TemplateOut)
def update_template(
    template_id: str,
    payload: schemas.TemplateUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    template = db.query(models.Template).filter(models.Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan")
    if template.is_system:
        raise HTTPException(status_code=403, detail="Template sistem tidak bisa diedit")
    if template.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan template milikmu")

    for key, value in payload.dict(exclude_unset=True).items():
        setattr(template, key, value)

    db.commit()
    db.refresh(template)
    return template


@router.delete("/{template_id}")
def delete_template(template_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    template = db.query(models.Template).filter(models.Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan")
    if template.is_system:
        raise HTTPException(status_code=403, detail="Template sistem tidak bisa dihapus")
    if template.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan template milikmu")
    db.delete(template)
    db.commit()
    return {"message": "Template dihapus"}

