from functools import lru_cache

from openai import OpenAI

from app.config import settings


@lru_cache(maxsize=1)
def _get_client() -> OpenAI:
    return OpenAI(api_key=settings.openai_api_key, base_url=settings.openai_base_url or None)


def complete(system_prompt: str, user_prompt: str) -> str:
    client = _get_client()
    response = client.chat.completions.create(
        model=settings.openai_model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    )
    return response.choices[0].message.content or ""


def chat(messages: list[dict[str, str]]) -> str:
    client = _get_client()
    response = client.chat.completions.create(model=settings.openai_model, messages=messages)
    return response.choices[0].message.content or ""
