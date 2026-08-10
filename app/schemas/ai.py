from pydantic import BaseModel


class SummarizeRequest(BaseModel):
    text: str


class SummarizeResponse(BaseModel):
    summary: str


class FixCodeRequest(BaseModel):
    code: str
    language: str | None = None
    instructions: str | None = None


class FixCodeResponse(BaseModel):
    fixed_code: str
    explanation: str


class DraftRequest(BaseModel):
    prompt: str


class DraftResponse(BaseModel):
    draft: str


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]


class ChatResponse(BaseModel):
    reply: str


class DocToPptRequest(BaseModel):
    stack_box_id: int
