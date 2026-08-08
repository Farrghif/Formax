from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import models, schemas
from ..deps import get_db, get_current_user

router = APIRouter(tags=["submissions"])


@router.post("/forms/public/{slug}/join", response_model=schemas.SubmissionStartOut)
def join_form(
    slug: str,
    payload: schemas.JoinFormRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Dipanggil pas user klik 'Mulai Isi Form' / 'Mulai Ujian'.
    - Kalau form.join_token diset, user WAJIB kirim token yang cocok (fitur ujian bareng).
    - Kalau ada start_date/end_date, dicek apakah sekarang ada di dalam window itu.
    - 1 user cuma boleh punya 1 submission per form (unique constraint) — kalau udah pernah
      mulai, submission yang sama dikembalikan lagi (biar bisa lanjut isi, bukan mulai dari 0).
    """
    form = db.query(models.Form).filter(models.Form.slug == slug).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.status != models.FormStatus.published or not form.accept_responses:
        raise HTTPException(status_code=403, detail="Form ini tidak menerima jawaban saat ini")

    if form.join_token:
        if not payload.token or payload.token.strip().upper() != form.join_token.upper():
            raise HTTPException(status_code=403, detail="Token salah atau belum diisi")

    now = datetime.utcnow()
    if form.start_date and now < form.start_date:
        raise HTTPException(status_code=403, detail="Form belum dibuka")
    if form.end_date and now > form.end_date:
        raise HTTPException(status_code=403, detail="Waktu pengisian form sudah berakhir")

    existing = (
        db.query(models.Submission)
        .filter(models.Submission.form_id == form.id, models.Submission.user_id == current_user.id)
        .first()
    )
    if existing:
        if existing.submitted_at is not None:
            raise HTTPException(status_code=400, detail="Kamu sudah submit form ini sebelumnya")
        return existing  # lanjutin submission yang belum selesai

    submission = models.Submission(form_id=form.id, user_id=current_user.id)
    db.add(submission)
    try:
        db.commit()
    except IntegrityError:
        # Race: dua request join (double click / double effect) sama-sama lolos pengecekan
        # "sudah ada submission?" sebelum ada yang commit. Constraint unik menolak INSERT
        # kedua — kembalikan submission yang sudah terlanjur dibuat.
        db.rollback()
        existing = (
            db.query(models.Submission)
            .filter(models.Submission.form_id == form.id, models.Submission.user_id == current_user.id)
            .first()
        )
        if existing:
            if existing.submitted_at is not None:
                raise HTTPException(status_code=400, detail="Kamu sudah submit form ini sebelumnya")
            return existing
        raise
    db.refresh(submission)
    return submission


@router.put("/submissions/{submission_id}/answers", response_model=schemas.AnswerOut)
def save_answer(
    submission_id: str,
    payload: schemas.AnswerSave,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Autosave — dipanggil tiap kali user jawab 1 soal (bukan nunggu submit akhir).
    Upsert berdasarkan (submission_id, question_id): kalau udah pernah jawab soal ini,
    di-update; kalau belum, dibikin baru. Ini juga yang jadi basis progress indikator.
    """
    submission = db.query(models.Submission).filter(models.Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission tidak ditemukan")
    if submission.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan submission milikmu")
    if submission.submitted_at is not None:
        raise HTTPException(status_code=400, detail="Form ini sudah kamu submit, tidak bisa diubah lagi")

    form = db.query(models.Form).filter(models.Form.id == submission.form_id).first()
    if form.end_date and datetime.utcnow() > form.end_date:
        raise HTTPException(status_code=403, detail="Waktu pengisian sudah habis")

    answer = (
        db.query(models.Answer)
        .filter(models.Answer.submission_id == submission_id, models.Answer.question_id == str(payload.question_id))
        .first()
    )
    if answer:
        answer.answer_text = payload.answer_text
        answer.answer_options = payload.answer_options
        answer.file_url = payload.file_url
    else:
        answer = models.Answer(
            submission_id=submission_id, question_id=payload.question_id,
            answer_text=payload.answer_text, answer_options=payload.answer_options, file_url=payload.file_url,
        )
        db.add(answer)

    db.commit()
    db.refresh(answer)
    return answer


@router.get("/submissions/{submission_id}/progress", response_model=schemas.ProgressOut)
def get_progress(
    submission_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Buat indikator 'X/Y soal terjawab' di UI."""
    submission = db.query(models.Submission).filter(models.Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission tidak ditemukan")
    if submission.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan submission milikmu")

    total = db.query(func.count(models.Question.id)).filter(models.Question.form_id == submission.form_id).scalar()
    answered = db.query(func.count(models.Answer.id)).filter(models.Answer.submission_id == submission_id).scalar()
    return schemas.ProgressOut(answered=answered or 0, total=total or 0)


@router.post("/submissions/{submission_id}/submit", response_model=schemas.SubmissionOut)
def submit_final(
    submission_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Finalisasi submission. Kalau waktunya udah lewat end_date form, ditandai is_auto_submitted."""
    submission = db.query(models.Submission).filter(models.Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission tidak ditemukan")
    if submission.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan submission milikmu")
    if submission.submitted_at is not None:
        raise HTTPException(status_code=400, detail="Sudah pernah disubmit")

    form = db.query(models.Form).filter(models.Form.id == submission.form_id).first()
    now = datetime.utcnow()
    if form.end_date and now > form.end_date:
        submission.is_auto_submitted = True

    submission.submitted_at = now
    db.commit()
    db.refresh(submission)
    return submission


@router.get("/forms/{form_id}/submissions", response_model=List[schemas.SubmissionOut])
def list_submissions_for_form(
    form_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Halaman 'Lihat Respon' — owner form lihat semua jawaban yang masuk."""
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    return db.query(models.Submission).filter(models.Submission.form_id == form_id).all()

