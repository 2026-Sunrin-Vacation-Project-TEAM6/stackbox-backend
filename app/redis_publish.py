import json
from functools import lru_cache
from typing import Any

import redis

from app.config import settings


@lru_cache(maxsize=1)
def _get_client() -> redis.Redis:
    return redis.Redis.from_url(settings.redis_url, decode_responses=True)


def room_stream_key(stack_box_id: int) -> str:
    return f"{settings.redis_stream_prefix}:{stack_box_id}"


def publish_event(stack_box_id: int, message: dict[str, Any], user_id: int | None = None) -> None:
    client = _get_client()
    client.xadd(
        room_stream_key(stack_box_id),
        {"message": json.dumps(message), "user_id": str(user_id) if user_id is not None else ""},
    )
