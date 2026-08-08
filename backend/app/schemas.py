import uuid
from datetime import datetime
from typing import Optional, List, Any
from pydantic import BaseModel, EmailStr

from .models import QuestionType, FormStatus


# ============================================================
# AUTH
# ============================================================
class SignUpRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    otp: str


class SendOTPRequest(BaseModel):
    email: EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    avatar_url: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: uuid.UUID
    full_name: str
    email: EmailStr
    avatar_url: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# QUESTION OPTIONS
# ============================================================
class QuestionOptionCreate(BaseModel):
    label: str
    value: Optional[str] = None
    order_index: int = 0
    is_correct: bool = False


class QuestionOptionUpdate(BaseModel):
    label: Optional[str] = None
    value: Optional[str] = None
    order_index: Optional[int] = None
    is_correct: Optional[bool] = None


class QuestionOptionOut(QuestionOptionCreate):
    id: uuid.UUID

    class Config:
        from_attributes = True


# ============================================================
# QUESTIONS
# ============================================================
class QuestionCreate(BaseModel):
    type: QuestionType
    label: str
    placeholder: Optional[str] = None
    is_required: bool = False
    order_index: int = 0
    settings: dict = {}
    options: List[QuestionOptionCreate] = []


class QuestionUpdate(BaseModel):
    type: Optional[QuestionType] = None
    label: Optional[str] = None
    placeholder: Optional[str] = None
    is_required: Optional[bool] = None
    order_index: Optional[int] = None
    settings: Optional[dict] = None


class QuestionOut(BaseModel):
    id: uuid.UUID
    type: QuestionType
    label: str
    placeholder: Optional[str]
    is_required: bool
    order_index: int
    settings: dict
    options: List[QuestionOptionOut] = []

    class Config:
        from_attributes = True


# ============================================================
# TEMPLATES
# ============================================================
class TemplateCreate(BaseModel):
    title: str
    description: Optional[str] = None
    questions: List[QuestionCreate] = []


class TemplateUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None


class TemplateOut(BaseModel):
    id: uuid.UUID
    owner_id: Optional[uuid.UUID]
    title: str
    description: Optional[str]
    is_system: bool
    created_at: datetime
    questions: List[QuestionOut] = []

    class Config:
        from_attributes = True


# ============================================================
# FORMS
# ============================================================
class FormCreate(BaseModel):
    title: str
    description: Optional[str] = None
    template_id: Optional[uuid.UUID] = None
    slug: str
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    use_join_token: bool = False        # kalau true, server generate token acak buat ujian bareng
    questions: List[QuestionCreate] = []  # dipakai kalau blank form (tanpa template)


class FormUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[FormStatus] = None
    accept_responses: Optional[bool] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None


class FormOut(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    template_id: Optional[uuid.UUID]
    title: str
    description: Optional[str]
    status: FormStatus
    slug: str
    join_token: Optional[str]
    qr_code_url: Optional[str]
    accept_responses: bool
    start_date: Optional[datetime]
    end_date: Optional[datetime]
    created_at: datetime
    questions: List[QuestionOut] = []

    class Config:
        from_attributes = True


class FormListOut(BaseModel):
    id: uuid.UUID
    title: str
    status: FormStatus
    slug: str
    created_at: datetime
    total_submissions: int = 0   # dihitung on-the-fly, buat halaman History

    class Config:
        from_attributes = True


# ============================================================
# JOIN / SUBMISSION / ANSWERS
# ============================================================
class JoinFormRequest(BaseModel):
    token: Optional[str] = None   # wajib diisi kalau form.join_token gak null


class SubmissionStartOut(BaseModel):
    id: uuid.UUID
    form_id: uuid.UUID
    started_at: datetime

    class Config:
        from_attributes = True


class AnswerSave(BaseModel):
    question_id: uuid.UUID
    answer_text: Optional[str] = None
    answer_options: Optional[List[str]] = None
    file_url: Optional[str] = None


class AnswerOut(BaseModel):
    id: uuid.UUID
    question_id: uuid.UUID
    answer_text: Optional[str]
    answer_options: Optional[Any]
    file_url: Optional[str]

    class Config:
        from_attributes = True


class ProgressOut(BaseModel):
    answered: int
    total: int


class SubmissionOut(BaseModel):
    id: uuid.UUID
    form_id: uuid.UUID
    user_id: uuid.UUID
    user: Optional[UserOut] = None
    started_at: datetime
    is_auto_submitted: bool
    submitted_at: Optional[datetime]
    answers: List[AnswerOut] = []

    class Config:
        from_attributes = True
