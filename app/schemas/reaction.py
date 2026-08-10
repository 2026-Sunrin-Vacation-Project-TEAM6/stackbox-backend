from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ReactionCreate(BaseModel):
    emoji_code: str = Field(max_length=64)


class ReactionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    stack_box_id: int
    user_id: int
    emoji_code: str
    created_at: datetime


class EmojiCatalogEntry(BaseModel):
    code: str
    label: str
    image_path: str
