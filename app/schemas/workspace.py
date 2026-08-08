from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.workspace import WorkspaceRole


class WorkspaceBase(BaseModel):
    name: str = Field(max_length=255)
    slug: str = Field(max_length=100)
    description: str = ""
    icon: str | None = Field(default=None, max_length=64)
    owner_id: int


class WorkspaceCreate(WorkspaceBase):
    pass


class WorkspaceUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=255)
    slug: str | None = Field(default=None, max_length=100)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    owner_id: int | None = None


class WorkspaceRead(WorkspaceBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime


class WorkspaceMemberBase(BaseModel):
    user_id: int
    role: WorkspaceRole = WorkspaceRole.viewer
    invited_by: int | None = None


class WorkspaceMemberCreate(WorkspaceMemberBase):
    pass


class WorkspaceMemberUpdate(BaseModel):
    role: WorkspaceRole | None = None


class WorkspaceMemberRead(WorkspaceMemberBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    workspace_id: int
    joined_at: datetime
