from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CodeExecuteRequest(BaseModel):
    stdin: str | None = None


class CodeRunRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    block_id: int
    language: str = Field(max_length=32)
    stdout: str
    stderr: str
    exit_code: int
    duration_ms: int
    executed_by: int | None
    created_at: datetime
