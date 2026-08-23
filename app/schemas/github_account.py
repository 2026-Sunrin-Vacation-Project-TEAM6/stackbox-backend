from datetime import datetime

from pydantic import BaseModel, ConfigDict


class GithubAccountRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    github_user_id: str
    github_login: str
    connected_at: datetime


class GithubRepoRead(BaseModel):
    owner: str
    name: str
    full_name: str
    private: bool
    default_branch: str


class GithubContentRead(BaseModel):
    path: str
    name: str
    type: str
    download_url: str | None = None


class GithubImportRequest(BaseModel):
    owner: str
    repo: str
    paths: list[str]
    stack_box_id: int


class GithubImportResult(BaseModel):
    imported: int
    block_ids: list[int]
