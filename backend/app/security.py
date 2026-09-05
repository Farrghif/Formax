import os
import secrets
from datetime import datetime, timedelta
from typing import Optional

from jose import jwt, JWTError
from passlib.context import CryptContext

from dotenv import load_dotenv

load_dotenv()

_env_secret = os.getenv("SECRET_KEY")
if not _env_secret or _env_secret.strip() == "" or _env_secret in ("change-this-secret-in-production", "ganti-dengan-random-string-panjang-dan-rahasia"):
    _env_secret = "form4x_secure_secret_key_8f9a2b3c4d5e6f7a8b9c0d1e2f3a4b5c"

SECRET_KEY = _env_secret
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 hari default
REMEMBER_ME_EXPIRE_MINUTES = 60 * 24 * 30  # 30 hari untuk remember me

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    return pwd_context.verify(plain_password, password_hash)


def create_access_token(data: dict, expires_minutes: int = ACCESS_TOKEN_EXPIRE_MINUTES) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=expires_minutes)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return None


def generate_join_token(length: int = 6) -> str:
    """Generate kode pendek buat fitur ujian bareng, ex: 'K3F9QZ'."""
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # tanpa karakter yang gampang ketuker (0/O, 1/I)
    return "".join(secrets.choice(alphabet) for _ in range(length))
