from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.access import require_workspace_role
from app.config import settings
from app.crypto import decrypt_token, encrypt_token
from app.database import get_db
from app.dependencies import get_current_user
from app.models.block import Block, BlockType
from app.models.github_account import GithubAccount
from app.models.stack_box import StackBox
from app.models.user import User
from app.models.workspace import WorkspaceRole
from app.schemas.github_account import (
    GithubAccountRead,
    GithubContentRead,
    GithubImportRequest,
    GithubImportResult,
    GithubRepoRead,
)
from app.security import create_oauth_state_token, decode_oauth_state_token

router = APIRouter(prefix="/github", tags=["github"])

GITHUB_AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
GITHUB_API_URL = "https://api.github.com"

_LANGUAGE_BY_EXTENSION = {
    "py": "python",
    "js": "javascript",
    "ts": "typescript",
    "tsx": "typescript",
    "jsx": "javascript",
    "rs": "rust",
    "go": "go",
    "rb": "ruby",
    "java": "java",
    "c": "c",
    "cpp": "cpp",
    "sh": "bash",
    "md": "markdown",
    "json": "json",
    "yml": "yaml",
    "yaml": "yaml",
}


def _get_stack_box_or_404(db: Session, stack_box_id: int) -> StackBox:
    stack_box = db.get(StackBox, stack_box_id)
    if stack_box is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="StackBox not found")
    return stack_box


def _get_account_or_404(db: Session, user_id: int) -> GithubAccount:
    account = db.query(GithubAccount).filter(GithubAccount.user_id == user_id).first()
    if account is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="GitHub account not connected")
    return account


def _infer_language(path: str) -> str | None:
    if "." not in path:
        return None
    ext = path.rsplit(".", 1)[-1].lower()
    return _LANGUAGE_BY_EXTENSION.get(ext)


@router.get("/oauth/login")
def github_oauth_login(current_user: User = Depends(get_current_user)) -> RedirectResponse:
    state = create_oauth_state_token(current_user.id)
    params = {
        "client_id": settings.github_client_id,
        "redirect_uri": settings.github_oauth_redirect_uri,
        "scope": "repo read:user",
        "state": state,
    }
    return RedirectResponse(url=f"{GITHUB_AUTHORIZE_URL}?{urlencode(params)}")


@router.get("/oauth/callback")
def github_oauth_callback(
    code: str = Query(...),
    state: str = Query(...),
    db: Session = Depends(get_db),
) -> RedirectResponse:
    try:
        user_id = decode_oauth_state_token(state)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="invalid state") from exc

    token_response = httpx.post(
        GITHUB_TOKEN_URL,
        headers={"Accept": "application/json"},
        data={
            "client_id": settings.github_client_id,
            "client_secret": settings.github_client_secret,
            "code": code,
            "redirect_uri": settings.github_oauth_redirect_uri,
        },
        timeout=10.0,
    )
    token_response.raise_for_status()
    token_data = token_response.json()
    access_token = token_data.get("access_token")
    if not access_token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="GitHub token exchange failed")

    user_response = httpx.get(
        f"{GITHUB_API_URL}/user",
        headers={"Authorization": f"Bearer {access_token}", "Accept": "application/vnd.github+json"},
        timeout=10.0,
    )
    user_response.raise_for_status()
    github_user = user_response.json()

    account = db.query(GithubAccount).filter(GithubAccount.user_id == user_id).first()
    encrypted = encrypt_token(access_token)
    if account is None:
        account = GithubAccount(
            user_id=user_id,
            github_user_id=str(github_user["id"]),
            github_login=github_user["login"],
            access_token_encrypted=encrypted,
        )
        db.add(account)
    else:
        account.github_user_id = str(github_user["id"])
        account.github_login = github_user["login"]
        account.access_token_encrypted = encrypted

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This GitHub account is already linked to another StackBox user",
        )

    return RedirectResponse(url=f"{settings.frontend_base_url}/github?connected=1")


@router.get("/account", response_model=GithubAccountRead)
def get_account(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
) -> GithubAccount:
    return _get_account_or_404(db, current_user.id)


@router.get("/repos", response_model=list[GithubRepoRead])
def list_repos(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
) -> list[GithubRepoRead]:
    account = _get_account_or_404(db, current_user.id)
    token = decrypt_token(account.access_token_encrypted)
    response = httpx.get(
        f"{GITHUB_API_URL}/user/repos",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"},
        params={"per_page": 100, "sort": "updated"},
        timeout=10.0,
    )
    response.raise_for_status()
    repos = response.json()
    return [
        GithubRepoRead(
            owner=repo["owner"]["login"],
            name=repo["name"],
            full_name=repo["full_name"],
            private=repo["private"],
            default_branch=repo["default_branch"],
        )
        for repo in repos
    ]


@router.get("/repos/{owner}/{repo}/contents", response_model=list[GithubContentRead])
def list_contents(
    owner: str,
    repo: str,
    path: str = Query(default=""),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[GithubContentRead]:
    account = _get_account_or_404(db, current_user.id)
    token = decrypt_token(account.access_token_encrypted)
    response = httpx.get(
        f"{GITHUB_API_URL}/repos/{owner}/{repo}/contents/{path}",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"},
        timeout=10.0,
    )
    response.raise_for_status()
    items = response.json()
    if isinstance(items, dict):
        items = [items]
    return [
        GithubContentRead(
            path=item["path"], name=item["name"], type=item["type"], download_url=item.get("download_url")
        )
        for item in items
    ]


@router.post("/import", response_model=GithubImportResult, status_code=status.HTTP_201_CREATED)
def import_files(
    payload: GithubImportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> GithubImportResult:
    stack_box = _get_stack_box_or_404(db, payload.stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.editor)
    account = _get_account_or_404(db, current_user.id)
    token = decrypt_token(account.access_token_encrypted)

    block_ids: list[int] = []
    max_sort = db.query(Block).filter(Block.stack_box_id == stack_box.id).count()
    for offset, path in enumerate(payload.paths):
        content_response = httpx.get(
            f"{GITHUB_API_URL}/repos/{payload.owner}/{payload.repo}/contents/{path}",
            headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github.raw+json"},
            timeout=10.0,
        )
        content_response.raise_for_status()
        block = Block(
            stack_box_id=stack_box.id,
            type=BlockType.code,
            language=_infer_language(path),
            content=content_response.text,
            sort_order=max_sort + offset,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
        db.add(block)
        db.flush()
        block_ids.append(block.id)

    db.commit()
    return GithubImportResult(imported=len(block_ids), block_ids=block_ids)
