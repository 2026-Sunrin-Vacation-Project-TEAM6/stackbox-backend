import time

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.access import require_workspace_role
from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models.block import Block, BlockType
from app.models.code_run import CodeRun
from app.models.stack_box import StackBox
from app.models.user import User
from app.models.workspace import WorkspaceRole
from app.redis_publish import publish_event
from app.schemas.code_run import CodeExecuteRequest, CodeRunRead

router = APIRouter(tags=["code-execution"])


def _get_block_or_404(db: Session, block_id: int) -> Block:
    block = db.get(Block, block_id)
    if block is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Block not found")
    return block


def _get_stack_box_or_404(db: Session, stack_box_id: int) -> StackBox:
    stack_box = db.get(StackBox, stack_box_id)
    if stack_box is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="StackBox not found")
    return stack_box


@router.post("/blocks/{block_id}/run", response_model=CodeRunRead, status_code=status.HTTP_201_CREATED)
def run_block(
    block_id: int,
    payload: CodeExecuteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CodeRun:
    block = _get_block_or_404(db, block_id)
    if block.type != BlockType.code:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Block is not a code block")
    stack_box = _get_stack_box_or_404(db, block.stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.editor)

    language = block.language or "python"
    start = time.monotonic()
    try:
        response = httpx.post(
            f"{settings.code_runner_url}/execute",
            json={"language": language, "code": block.content.strip(), "stdin": payload.stdin},
            headers={"X-Code-Runner-Token": settings.code_runner_auth_token},
            timeout=15.0,
        )
        response.raise_for_status()
        result = response.json()
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=f"code runner unavailable: {exc}"
        ) from exc

    duration_ms = result.get("duration_ms", int((time.monotonic() - start) * 1000))
    code_run = CodeRun(
        block_id=block.id,
        language=language,
        stdout=result.get("stdout", ""),
        stderr=result.get("stderr", ""),
        exit_code=result.get("exit_code", 0),
        duration_ms=duration_ms,
        executed_by=current_user.id,
    )
    db.add(code_run)
    db.commit()
    db.refresh(code_run)

    publish_event(
        stack_box.id,
        {
            "type": "code_result",
            "block_id": block.id,
            "stdout": code_run.stdout,
            "stderr": code_run.stderr,
            "exit_code": code_run.exit_code,
            "duration_ms": code_run.duration_ms,
        },
        user_id=current_user.id,
    )

    return code_run


@router.get("/blocks/{block_id}/runs", response_model=list[CodeRunRead])
def list_runs(
    block_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[CodeRun]:
    block = _get_block_or_404(db, block_id)
    stack_box = _get_stack_box_or_404(db, block.stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.viewer)
    return (
        db.query(CodeRun)
        .filter(CodeRun.block_id == block_id)
        .order_by(CodeRun.created_at.desc())
        .limit(20)
        .all()
    )
