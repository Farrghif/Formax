import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..deps import get_db, get_current_user

router = APIRouter(prefix="", tags=["questions"])


@router.post("/forms/{form_id}/questions", response_model=schemas.QuestionOut)
def create_question_in_form(
    form_id: uuid.UUID,
    payload: schemas.QuestionCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    question = models.Question(form_id=form.id, type=payload.type, label=payload.label,
                               placeholder=payload.placeholder, is_required=payload.is_required,
                               order_index=payload.order_index, settings=payload.settings)
    db.add(question)
    db.flush()

    for opt in payload.options:
        db.add(models.QuestionOption(question_id=question.id, label=opt.label, value=opt.value, order_index=opt.order_index))

    db.commit()
    db.refresh(question)
    return question


@router.post("/templates/{template_id}/questions", response_model=schemas.QuestionOut)
def create_question_in_template(
    template_id: uuid.UUID,
    payload: schemas.QuestionCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    template = db.query(models.Template).filter(models.Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan")
    if template.is_system:
        raise HTTPException(status_code=403, detail="Template sistem tidak bisa diubah")
    if template.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan template milikmu")

    question = models.Question(template_id=template.id, type=payload.type, label=payload.label,
                               placeholder=payload.placeholder, is_required=payload.is_required,
                               order_index=payload.order_index, settings=payload.settings)
    db.add(question)
    db.flush()

    for opt in payload.options:
        db.add(models.QuestionOption(question_id=question.id, label=opt.label, value=opt.value, order_index=opt.order_index))

    db.commit()
    db.refresh(question)
    return question


@router.patch("/questions/{question_id}", response_model=schemas.QuestionOut)
def update_question(
    question_id: uuid.UUID,
    payload: schemas.QuestionUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    question = db.query(models.Question).filter(models.Question.id == question_id).first()
    if not question:
        raise HTTPException(status_code=404, detail="Pertanyaan tidak ditemukan")

    if question.form_id:
        form = db.query(models.Form).filter(models.Form.id == question.form_id).first()
        if not form or form.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan form milikmu")
    elif question.template_id:
        template = db.query(models.Template).filter(models.Template.id == question.template_id).first()
        if not template or template.is_system or template.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan template milikmu")

    for key, value in payload.dict(exclude_unset=True).items():
        setattr(question, key, value)

    db.commit()
    db.refresh(question)
    return question


@router.delete("/questions/{question_id}")
def delete_question(
    question_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    question = db.query(models.Question).filter(models.Question.id == question_id).first()
    if not question:
        raise HTTPException(status_code=404, detail="Pertanyaan tidak ditemukan")

    if question.form_id:
        form = db.query(models.Form).filter(models.Form.id == question.form_id).first()
        if not form or form.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan form milikmu")
    elif question.template_id:
        template = db.query(models.Template).filter(models.Template.id == question.template_id).first()
        if not template or template.is_system or template.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan template milikmu")

    db.delete(question)
    db.commit()
    return {"message": "Pertanyaan dihapus"}


@router.post("/questions/{question_id}/options", response_model=schemas.QuestionOptionOut)
def create_option(
    question_id: uuid.UUID,
    payload: schemas.QuestionOptionCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    question = db.query(models.Question).filter(models.Question.id == question_id).first()
    if not question:
        raise HTTPException(status_code=404, detail="Pertanyaan tidak ditemukan")

    if question.form_id:
        form = db.query(models.Form).filter(models.Form.id == question.form_id).first()
        if not form or form.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan form milikmu")
    elif question.template_id:
        template = db.query(models.Template).filter(models.Template.id == question.template_id).first()
        if not template or template.is_system or template.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan template milikmu")

    option = models.QuestionOption(question_id=question.id, label=payload.label, value=payload.value,
                                   order_index=payload.order_index)
    db.add(option)
    db.commit()
    db.refresh(option)
    return option


@router.patch("/options/{option_id}", response_model=schemas.QuestionOptionOut)
def update_option(
    option_id: uuid.UUID,
    payload: schemas.QuestionOptionUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    option = db.query(models.QuestionOption).filter(models.QuestionOption.id == option_id).first()
    if not option:
        raise HTTPException(status_code=404, detail="Opsi tidak ditemukan")

    question = option.question
    if question.form_id:
        form = db.query(models.Form).filter(models.Form.id == question.form_id).first()
        if not form or form.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan form milikmu")
    elif question.template_id:
        template = db.query(models.Template).filter(models.Template.id == question.template_id).first()
        if not template or template.is_system or template.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan template milikmu")

    for key, value in payload.dict(exclude_unset=True).items():
        setattr(option, key, value)

    db.commit()
    db.refresh(option)
    return option


@router.delete("/options/{option_id}")
def delete_option(
    option_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    option = db.query(models.QuestionOption).filter(models.QuestionOption.id == option_id).first()
    if not option:
        raise HTTPException(status_code=404, detail="Opsi tidak ditemukan")

    question = option.question
    if question.form_id:
        form = db.query(models.Form).filter(models.Form.id == question.form_id).first()
        if not form or form.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan form milikmu")
    elif question.template_id:
        template = db.query(models.Template).filter(models.Template.id == question.template_id).first()
        if not template or template.is_system or template.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan template milikmu")

    db.delete(option)
    db.commit()
    return {"message": "Opsi dihapus"}
