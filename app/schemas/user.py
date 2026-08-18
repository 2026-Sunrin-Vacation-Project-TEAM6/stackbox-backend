from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class UserBase(BaseModel):
    email: str = Field(max_length=255)
    name: str = Field(max_length=100)
    avatar_url: str | None = Field(default=None, max_length=512)
    is_active: bool = True


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    email: str | None = Field(default=None, max_length=255)
    name: str | None = Field(default=None, max_length=100)
    avatar_url: str | None = Field(default=None, max_length=512)


class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime
