from functools import lru_cache

from cryptography.fernet import Fernet

from app.config import settings


@lru_cache(maxsize=1)
def _get_fernet() -> Fernet:
    key = settings.token_encryption_key
    if not key:
        raise RuntimeError("token_encryption_key is not configured")
    return Fernet(key.encode("utf-8"))


def encrypt_token(plaintext: str) -> str:
    return _get_fernet().encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt_token(ciphertext: str) -> str:
    return _get_fernet().decrypt(ciphertext.encode("utf-8")).decode("utf-8")
