from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.workspace import Workspace, WorkspaceMember, WorkspaceRole

_ROLE_RANK: dict[WorkspaceRole, int] = {
    WorkspaceRole.viewer: 0,
    WorkspaceRole.editor: 1,
    WorkspaceRole.admin: 2,
    WorkspaceRole.owner: 3,
}


def get_workspace_role(db: Session, workspace_id: int, user_id: int) -> WorkspaceRole | None:
    workspace = db.get(Workspace, workspace_id)
    if workspace is None:
        return None
    if workspace.owner_id == user_id:
        return WorkspaceRole.owner

    member = (
        db.query(WorkspaceMember)
        .filter(WorkspaceMember.workspace_id == workspace_id, WorkspaceMember.user_id == user_id)
        .first()
    )
    return member.role if member else None


def require_workspace_role(
    db: Session, workspace_id: int, user: User, minimum: WorkspaceRole
) -> WorkspaceRole:
    role = get_workspace_role(db, workspace_id, user.id)
    if role is None or _ROLE_RANK[role] < _ROLE_RANK[minimum]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient workspace permissions",
        )
    return role
