from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.block import BlockType


class BlockBase(BaseModel):
    type: BlockType = BlockType.markdown
    language: str | None = Field(default=None, max_length=32)
    content: str = ""
    sort_order: int = 0
    pos_x: float | None = None
    pos_y: float | None = None
    width: float | None = None
    height: float | None = None


class BlockCreate(BlockBase):
    pass


class BlockUpdate(BaseModel):
    type: BlockType | None = None
    language: str | None = Field(default=None, max_length=32)
    content: str | None = None
    sort_order: int | None = None
    pos_x: float | None = None
    pos_y: float | None = None
    width: float | None = None
    height: float | None = None


class BlockRead(BlockBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    stack_box_id: int
    created_by: int | None
    updated_by: int | None
    created_at: datetime
    updated_at: datetime


class BlockReorder(BaseModel):
    sort_order: int
