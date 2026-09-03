import random
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..deps import get_db, get_current_user
from ..utils.mail import send_otp_email

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/send-otp")
def send_otp(payload: schemas.SendOTPRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    existing = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")

    otp_code = str(random.randint(100000, 999999))

    verification = models.EmailVerification(
        email=email,
        otp_code=otp_code,
        expires_at=datetime.utcnow() + timedelta(minutes=5)
    )
    db.add(verification)
    db.commit()

    background_tasks.add_task(send_otp_email, email, otp_code)

    return {"message": "OTP berhasil dikirim"}


@router.post("/forgot-password/send-otp")
def forgot_password_send_otp(
    payload: schemas.ForgotPasswordSendOTPRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    email = str(payload.email).strip().lower()
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if not user:
        raise HTTPException(status_code=400, detail="Email tidak terdaftar")

    otp_code = str(random.randint(100000, 999999))

    # Hapus verifikasi lama jika ada
    db.query(models.EmailVerification).filter(func.lower(models.EmailVerification.email) == email).delete()

    verification = models.EmailVerification(
        email=email,
        otp_code=otp_code,
        expires_at=datetime.utcnow() + timedelta(minutes=5)
    )
    db.add(verification)
    db.commit()

    background_tasks.add_task(send_otp_email, email, otp_code)

    return {"message": "Kode OTP untuk reset password telah dikirim ke email Anda"}


@router.post("/forgot-password/verify-otp")
def forgot_password_verify_otp(
    payload: schemas.ForgotPasswordVerifyOTPRequest,
    db: Session = Depends(get_db)
):
    email = str(payload.email).strip().lower()
    otp_record = (
        db.query(models.EmailVerification)
        .filter(func.lower(models.EmailVerification.email) == email)
        .filter(models.EmailVerification.otp_code == payload.otp)
        .first()
    )
    if not otp_record:
        raise HTTPException(status_code=400, detail="Kode OTP salah atau tidak valid")

    if otp_record.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Kode OTP sudah kedaluwarsa")

    return {"message": "Kode OTP valid", "valid": True}


@router.post("/forgot-password/reset-password")
def reset_password(
    payload: schemas.ResetPasswordRequest,
    db: Session = Depends(get_db)
):
    email = str(payload.email).strip().lower()
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if not user:
        raise HTTPException(status_code=400, detail="Email tidak terdaftar")

    otp_record = (
        db.query(models.EmailVerification)
        .filter(func.lower(models.EmailVerification.email) == email)
        .filter(models.EmailVerification.otp_code == payload.otp)
        .first()
    )
    if not otp_record:
        raise HTTPException(status_code=400, detail="Kode OTP tidak valid")

    if otp_record.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Kode OTP sudah kedaluwarsa")

    if len(payload.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password baru minimal 6 karakter")

    user.password_hash = security.hash_password(payload.new_password)
    db.add(user)

    db.query(models.EmailVerification).filter(func.lower(models.EmailVerification.email) == email).delete()

    db.commit()
    return {"message": "Password berhasil diubah. Silakan login kembali dengan password baru Anda."}


@router.post("/signup", response_model=schemas.TokenResponse)
def signup(payload: schemas.SignUpRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    otp_record = (
        db.query(models.EmailVerification)
        .filter(func.lower(models.EmailVerification.email) == email)
        .filter(models.EmailVerification.otp_code == payload.otp)
        .first()
    )
    if not otp_record:
        raise HTTPException(status_code=400, detail="OTP tidak valid")
    
    if otp_record.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="OTP sudah kedaluwarsa")
    
    db.query(models.EmailVerification).filter(func.lower(models.EmailVerification.email) == email).delete()

    existing = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")

    user = models.User(
        full_name=payload.full_name.strip(),
        email=email,
        password_hash=security.hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = security.create_access_token({"sub": str(user.id)})
    return schemas.TokenResponse(access_token=token)


@router.post("/login", response_model=schemas.TokenResponse)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if not user or not security.verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email atau password salah")

    token = security.create_access_token({"sub": str(user.id)})
    return schemas.TokenResponse(access_token=token)


@router.post("/logout")
def logout(current_user: models.User = Depends(get_current_user)):
    # JWT stateless: cukup instruksikan client hapus token yang tersimpan.
    return {"message": "Logout berhasil, hapus token di sisi client"}


@router.get("/me", response_model=schemas.UserOut)
def get_me(current_user: models.User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=schemas.UserOut)
def update_me(
    payload: schemas.ProfileUpdateRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if payload.full_name is not None:
        if not payload.full_name.strip():
            raise HTTPException(status_code=400, detail="Nama lengkap tidak boleh kosong")
        current_user.full_name = payload.full_name.strip()

    if payload.email is not None:
        email = str(payload.email).strip().lower()
        existing_user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
        if existing_user and existing_user.id != current_user.id:
            raise HTTPException(status_code=400, detail="Email sudah terdaftar")
        current_user.email = email

    if payload.avatar_url is not None:
        current_user.avatar_url = payload.avatar_url

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.put("/change-password")
def change_password(
    payload: schemas.ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if not security.verify_password(payload.old_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Password lama Anda salah")

    if len(payload.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password baru minimal 6 karakter")

    current_user.password_hash = security.hash_password(payload.new_password)
    db.add(current_user)
    db.commit()

    return {"message": "Password berhasil diubah"}
