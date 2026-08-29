from typing import Optional
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from .database import SessionLocal
from . import models
from .security import decode_access_token

security_scheme = HTTPBearer()
security_scheme_optional = HTTPBearer(auto_error=False)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: Session = Depends(get_db),
) -> models.User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token tidak valid atau kadaluarsa, silakan login ulang",
        headers={"WWW-Authenticate": "Bearer"},
    )
    token = credentials.credentials
    payload = decode_access_token(token)
    if payload is None or "sub" not in payload:
        raise credentials_exception

    user = db.query(models.User).filter(models.User.id == str(payload["sub"])).first()
    if user is None:
        raise credentials_exception
    return user


def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme_optional),
    db: Session = Depends(get_db),
) -> Optional[models.User]:
    """Return the logged-in user or None if not authenticated.

    Mirip get_current_user, tapi TIDAK melempar error ketika token tidak ada/tidak valid.
    Dipakai untuk alur isi form anonim (Google-Forms style): kalau login, identitasnya =
    user.id; kalau tidak, pakai respondent_key.
    """
    try:
        if credentials is None:
            return None
        token = credentials.credentials
        payload = decode_access_token(token)
        if payload is None or "sub" not in payload:
            return None
        user = db.query(models.User).filter(models.User.id == str(payload["sub"])).first()
        return user
    except Exception:
        return None


def get_respondent_key(x_respondent_key: Optional[str] = Header(default=None)) -> Optional[str]:
    """Anonymous identity: UUID string produced by the client (web/mobile) and sent
    in header X-Respondent-Key. Returned as-is; endpoints validate it."""
    return x_respondent_key

