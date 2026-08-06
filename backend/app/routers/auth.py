from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..deps import get_db, get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=schemas.TokenResponse)
def signup(payload: schemas.SignUpRequest, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == str(payload.email)).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")

    user = models.User(
        full_name=payload.full_name,
        email=payload.email,
        password_hash=security.hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = security.create_access_token({"sub": str(user.id)})
    return schemas.TokenResponse(access_token=token)


@router.post("/login", response_model=schemas.TokenResponse)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == str(payload.email)).first()
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
        existing_user = db.query(models.User).filter(models.User.email == str(payload.email)).first()
        if existing_user and existing_user.id != current_user.id:
            raise HTTPException(status_code=400, detail="Email sudah terdaftar")
        current_user.email = str(payload.email)

    if payload.avatar_url is not None:
        current_user.avatar_url = payload.avatar_url

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return current_user
