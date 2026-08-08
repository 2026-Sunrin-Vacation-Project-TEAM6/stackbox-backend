from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.workspace import Workspace, WorkspaceMember
from app.schemas.workspace import (
    WorkspaceCreate,
    WorkspaceMemberCreate,
    WorkspaceMemberRead,
    WorkspaceMemberUpdate,
    WorkspaceRead,
    WorkspaceUpdate,
)

router = APIRouter(prefix="/workspaces", tags=["workspaces"])


def _get_workspace_or_404(db: Session, workspace_id: int) -> Workspace:
    workspace = db.get(Workspace, workspace_id)
    if workspace is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workspace not found")
    return workspace


def _get_member_or_404(db: Session, workspace_id: int, member_id: int) -> WorkspaceMember:
    member = db.get(WorkspaceMember, member_id)
    if member is None or member.workspace_id != workspace_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workspace member not found")
    return member


@router.post("", response_model=WorkspaceRead, status_code=status.HTTP_201_CREATED)
def create_workspace(payload: WorkspaceCreate, db: Session = Depends(get_db)) -> Workspace:
    workspace = Workspace(**payload.model_dump())
    db.add(workspace)
    db.commit()
    db.refresh(workspace)
    return workspace


@router.get("", response_model=list[WorkspaceRead])
def list_workspaces(db: Session = Depends(get_db)) -> list[Workspace]:
    return db.query(Workspace).order_by(Workspace.id).all()


@router.get("/{workspace_id}", response_model=WorkspaceRead)
def get_workspace(workspace_id: int, db: Session = Depends(get_db)) -> Workspace:
    return _get_workspace_or_404(db, workspace_id)


@router.patch("/{workspace_id}", response_model=WorkspaceRead)
def update_workspace(
    workspace_id: int, payload: WorkspaceUpdate, db: Session = Depends(get_db)
) -> Workspace:
    workspace = _get_workspace_or_404(db, workspace_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(workspace, field, value)
    db.commit()
    db.refresh(workspace)
    return workspace


@router.delete("/{workspace_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_workspace(workspace_id: int, db: Session = Depends(get_db)) -> None:
    workspace = _get_workspace_or_404(db, workspace_id)
    db.delete(workspace)
    db.commit()


@router.post(
    "/{workspace_id}/members",
    response_model=WorkspaceMemberRead,
    status_code=status.HTTP_201_CREATED,
)
def add_workspace_member(
    workspace_id: int, payload: WorkspaceMemberCreate, db: Session = Depends(get_db)
) -> WorkspaceMember:
    _get_workspace_or_404(db, workspace_id)
    member = WorkspaceMember(workspace_id=workspace_id, **payload.model_dump())
    db.add(member)
    db.commit()
    db.refresh(member)
    return member


@router.get("/{workspace_id}/members", response_model=list[WorkspaceMemberRead])
def list_workspace_members(workspace_id: int, db: Session = Depends(get_db)) -> list[WorkspaceMember]:
    _get_workspace_or_404(db, workspace_id)
    return (
        db.query(WorkspaceMember)
        .filter(WorkspaceMember.workspace_id == workspace_id)
        .order_by(WorkspaceMember.id)
        .all()
    )


@router.patch("/{workspace_id}/members/{member_id}", response_model=WorkspaceMemberRead)
def update_workspace_member(
    workspace_id: int,
    member_id: int,
    payload: WorkspaceMemberUpdate,
    db: Session = Depends(get_db),
) -> WorkspaceMember:
    member = _get_member_or_404(db, workspace_id, member_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(member, field, value)
    db.commit()
    db.refresh(member)
    return member


@router.delete("/{workspace_id}/members/{member_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_workspace_member(workspace_id: int, member_id: int, db: Session = Depends(get_db)) -> None:
    member = _get_member_or_404(db, workspace_id, member_id)
    db.delete(member)
    db.commit()
