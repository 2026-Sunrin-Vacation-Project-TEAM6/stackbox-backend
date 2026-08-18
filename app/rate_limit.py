import time
from functools import lru_cache

import redis
from fastapi import HTTPException, status

from app.config import settings


@lru_cache(maxsize=1)
def _get_client() -> redis.Redis:
    return redis.Redis.from_url(settings.redis_url, decode_responses=True)


def enforce_rate_limit(key: str, limit: int, window_seconds: int) -> None:
    """Fixed-window rate limit shared across app instances via Redis.

    Raises 429 once `key` has been called more than `limit` times within
    the current `window_seconds` bucket.
    """
    client = _get_client()
    bucket = int(time.time()) // window_seconds
    redis_key = f"ratelimit:{key}:{bucket}"
    count = client.incr(redis_key)
    if count == 1:
        client.expire(redis_key, window_seconds)
    if count > limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded, please slow down and try again later",
        )
