import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.user import User
from app.models.user_session import UserSession
from app.schemas.auth import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse
from app.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _issue_tokens(db: Session, user: User) -> TokenResponse:
    refresh_token = secrets.token_urlsafe(32)
    session = UserSession(
        user_id=user.id,
        token_hash=_hash_token(refresh_token),
        expires_at=datetime.now(timezone.utc)
        + timedelta(days=settings.refresh_token_expire_days),
    )
    db.add(session)
    db.commit()

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=refresh_token,
    )


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    if db.query(User).filter(User.email == payload.email).first() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Email already registered"
        )

    user = User(
        email=payload.email,
        password_hash=hash_password(payload.password),
        name=payload.name,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return _issue_tokens(db, user)


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password"
    )

    user = db.query(User).filter(User.email == payload.email).first()
    if user is None or user.password_hash is None:
        raise unauthorized
    if not verify_password(payload.password, user.password_hash):
        raise unauthorized
    if not user.is_active:
        raise unauthorized

    return _issue_tokens(db, user)


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)) -> TokenResponse:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token"
    )

    token_hash = _hash_token(payload.refresh_token)
    session = db.query(UserSession).filter(UserSession.token_hash == token_hash).first()
    if session is None:
        raise unauthorized

    if session.expires_at < datetime.now(timezone.utc):
        db.delete(session)
        db.commit()
        raise unauthorized

    user = db.get(User, session.user_id)
    if user is None or not user.is_active:
        raise unauthorized

    db.delete(session)
    db.commit()

    return _issue_tokens(db, user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(payload: RefreshRequest, db: Session = Depends(get_db)) -> None:
    token_hash = _hash_token(payload.refresh_token)
    session = db.query(UserSession).filter(UserSession.token_hash == token_hash).first()
    if session is not None:
        db.delete(session)
        db.commit()
