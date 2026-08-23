from typing import Literal

from pydantic import BaseModel, Field


class SummarizeRequest(BaseModel):
    text: str = Field(max_length=20_000)


class SummarizeResponse(BaseModel):
    summary: str


class FixCodeRequest(BaseModel):
    code: str = Field(max_length=20_000)
    language: str | None = None
    instructions: str | None = Field(default=None, max_length=2_000)


class FixCodeResponse(BaseModel):
    fixed_code: str
    explanation: str


class DraftRequest(BaseModel):
    prompt: str = Field(max_length=4_000)


class DraftResponse(BaseModel):
    draft: str


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(max_length=8_000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=50)


class ChatResponse(BaseModel):
    reply: str


class DocToPptRequest(BaseModel):
    stack_box_id: int
