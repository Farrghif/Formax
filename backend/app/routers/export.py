import io
import uuid

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from openpyxl import Workbook

from .. import models
from ..deps import get_db, get_current_user

router = APIRouter(prefix="/forms", tags=["export"])


@router.get("/{form_id}/export")
def export_submissions_to_excel(
    form_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    questions = (
        db.query(models.Question)
        .filter(models.Question.form_id == form_id)
        .order_by(models.Question.order_index)
        .all()
    )
    submissions = db.query(models.Submission).filter(models.Submission.form_id == form_id).all()

    wb = Workbook()
    ws = wb.active
    ws.title = "Submissions"

    headers = ["Nama Pengisi", "Email", "Waktu Submit", "Auto-submit?"] + [q.label for q in questions]
    ws.append(headers)

    question_order = [q.id for q in questions]

    for sub in submissions:
        answers_by_question = {a.question_id: a for a in sub.answers}
        row = [
            sub.user.full_name if sub.user else "",
            sub.user.email if sub.user else "",
            sub.submitted_at.strftime("%Y-%m-%d %H:%M:%S") if sub.submitted_at else "Belum submit",
            "Ya" if sub.is_auto_submitted else "Tidak",
        ]
        for qid in question_order:
            ans = answers_by_question.get(qid)
            if not ans:
                row.append("")
            elif ans.answer_text:
                row.append(ans.answer_text)
            elif ans.answer_options:
                row.append(", ".join(ans.answer_options))
            elif ans.file_url:
                row.append(ans.file_url)
            else:
                row.append("")
        ws.append(row)

    buffer = io.BytesIO()
    wb.save(buffer)
    buffer.seek(0)

    filename = f"{form.slug}-hasil.xlsx"
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )
