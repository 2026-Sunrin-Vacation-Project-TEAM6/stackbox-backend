from datetime import datetime

from pydantic import BaseModel, ConfigDict


class DocSnapshotRead(BaseModel):
    stack_box_id: int
    blob: str
    state: str | None = None
    size: int
    version: int
    created_by: int | None = None
    updated_by: int | None = None
    created_at: datetime
    updated_at: datetime


class DocSnapshotUpsert(BaseModel):
    blob: str
    state: str | None = None
    created_by: int | None = None
    updated_by: int | None = None


class DocUpdateRead(BaseModel):
    id: int
    stack_box_id: int
    blob: str
    seq: int
    created_by: int | None = None
    created_at: datetime


class CanvasPresenceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    stack_box_id: int
    user_id: int
    cursor_x: float | None = None
    cursor_y: float | None = None
    selection: dict | None = None
    color: str | None = None
    last_seen_at: datetime
