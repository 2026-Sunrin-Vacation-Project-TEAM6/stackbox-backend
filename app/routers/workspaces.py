from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.access import require_workspace_role
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.workspace import Workspace, WorkspaceMember, WorkspaceRole
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
def create_workspace(
    payload: WorkspaceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Workspace:
    data = payload.model_dump()
    data["owner_id"] = current_user.id
    workspace = Workspace(**data)
    db.add(workspace)
    db.commit()
    db.refresh(workspace)
    return workspace


@router.get("", response_model=list[WorkspaceRead])
def list_workspaces(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[Workspace]:
    member_workspace_ids = (
        db.query(WorkspaceMember.workspace_id).filter(WorkspaceMember.user_id == current_user.id)
    )
    return (
        db.query(Workspace)
        .filter(
            (Workspace.owner_id == current_user.id)
            | (Workspace.id.in_(member_workspace_ids))
        )
        .order_by(Workspace.id)
        .all()
    )


@router.get("/{workspace_id}", response_model=WorkspaceRead)
def get_workspace(
    workspace_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Workspace:
    workspace = _get_workspace_or_404(db, workspace_id)
    require_workspace_role(db, workspace_id, current_user, WorkspaceRole.viewer)
    return workspace


@router.patch("/{workspace_id}", response_model=WorkspaceRead)
def update_workspace(
    workspace_id: int,
    payload: WorkspaceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Workspace:
    workspace = _get_workspace_or_404(db, workspace_id)
    require_workspace_role(db, workspace_id, current_user, WorkspaceRole.admin)
    for field, value in payload.model_dump(exclude_unset=True, exclude={"owner_id"}).items():
        setattr(workspace, field, value)
    db.commit()
    db.refresh(workspace)
    return workspace


@router.delete("/{workspace_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_workspace(
    workspace_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    workspace = _get_workspace_or_404(db, workspace_id)
    require_workspace_role(db, workspace_id, current_user, WorkspaceRole.owner)
    db.delete(workspace)
    db.commit()


@router.post(
    "/{workspace_id}/members",
    response_model=WorkspaceMemberRead,
    status_code=status.HTTP_201_CREATED,
)
def add_workspace_member(
    workspace_id: int,
    payload: WorkspaceMemberCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> WorkspaceMember:
    _get_workspace_or_404(db, workspace_id)
    require_workspace_role(db, workspace_id, current_user, WorkspaceRole.admin)
    if payload.role == WorkspaceRole.owner:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot grant owner role via membership"
        )
    data = payload.model_dump()
    data["invited_by"] = current_user.id
    member = WorkspaceMember(workspace_id=workspace_id, **data)
    db.add(member)
    db.commit()
    db.refresh(member)
    return member


@router.get("/{workspace_id}/members", response_model=list[WorkspaceMemberRead])
def list_workspace_members(
    workspace_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[WorkspaceMember]:
    _get_workspace_or_404(db, workspace_id)
    require_workspace_role(db, workspace_id, current_user, WorkspaceRole.viewer)
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
    current_user: User = Depends(get_current_user),
) -> WorkspaceMember:
    member = _get_member_or_404(db, workspace_id, member_id)
    require_workspace_role(db, workspace_id, current_user, WorkspaceRole.admin)
    if payload.role == WorkspaceRole.owner:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot grant owner role via membership"
        )
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(member, field, value)
    db.commit()
    db.refresh(member)
    return member


@router.delete("/{workspace_id}/members/{member_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_workspace_member(
    workspace_id: int,
    member_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    member = _get_member_or_404(db, workspace_id, member_id)
    if member.user_id != current_user.id:
        require_workspace_role(db, workspace_id, current_user, WorkspaceRole.admin)
    db.delete(member)
    db.commit()
