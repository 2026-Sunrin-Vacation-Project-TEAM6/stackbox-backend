from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.access import require_workspace_role
from app.database import get_db
from app.dependencies import get_current_user
from app.emoji_catalog import EMOJI_CATALOG
from app.models.reaction import Reaction
from app.models.stack_box import StackBox
from app.models.user import User
from app.models.workspace import WorkspaceRole
from app.schemas.reaction import EmojiCatalogEntry, ReactionCreate, ReactionRead

router = APIRouter(tags=["reactions"])


def _get_stack_box_or_404(db: Session, stack_box_id: int) -> StackBox:
    stack_box = db.get(StackBox, stack_box_id)
    if stack_box is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="StackBox not found")
    return stack_box


@router.get("/emoji/catalog", response_model=list[EmojiCatalogEntry])
def get_emoji_catalog() -> list[dict[str, str]]:
    return EMOJI_CATALOG


@router.get("/stack-boxes/{stack_box_id}/reactions", response_model=list[ReactionRead])
def list_reactions(
    stack_box_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
) -> list[Reaction]:
    stack_box = _get_stack_box_or_404(db, stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.viewer)
    return db.query(Reaction).filter(Reaction.stack_box_id == stack_box_id).all()


@router.post(
    "/stack-boxes/{stack_box_id}/reactions",
    response_model=ReactionRead,
    status_code=status.HTTP_201_CREATED,
)
def create_reaction(
    stack_box_id: int,
    payload: ReactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Reaction:
    stack_box = _get_stack_box_or_404(db, stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.viewer)

    reaction = Reaction(
        stack_box_id=stack_box_id, user_id=current_user.id, emoji_code=payload.emoji_code
    )
    db.add(reaction)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Reaction already exists"
        ) from exc
    db.refresh(reaction)
    return reaction


@router.delete("/reactions/{reaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_reaction(
    reaction_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
) -> None:
    reaction = db.get(Reaction, reaction_id)
    if reaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reaction not found")
    if reaction.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your reaction")
    db.delete(reaction)
    db.commit()
