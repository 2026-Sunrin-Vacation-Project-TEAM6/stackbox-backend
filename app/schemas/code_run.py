from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CodeExecuteRequest(BaseModel):
    stdin: str | None = Field(default=None, max_length=64_000)


class CodeRunRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    block_id: int
    language: str = Field(max_length=32)
    stdout: str
    stderr: str
    compile_error: str | None = None
    exit_code: int
    duration_ms: int
    executed_by: int | None
    created_at: datetime
