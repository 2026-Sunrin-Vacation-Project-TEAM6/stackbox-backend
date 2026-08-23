from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.stack_box import StackBoxType


class StackBoxBase(BaseModel):
    workspace_id: int
    parent_id: int | None = None
    type: StackBoxType = StackBoxType.folder
    name: str = Field(max_length=255)
    description: str = ""
    icon: str | None = Field(default=None, max_length=64)
    cover_url: str | None = Field(default=None, max_length=512)
    sort_order: int = 0


class StackBoxCreate(StackBoxBase):
    pass


class StackBoxUpdate(BaseModel):
    parent_id: int | None = None
    type: StackBoxType | None = None
    name: str | None = Field(default=None, max_length=255)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    cover_url: str | None = Field(default=None, max_length=512)
    sort_order: int | None = None


class StackBoxRead(StackBoxBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime
