from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.access import require_workspace_role
from app.database import get_db
from app.dependencies import get_current_user
from app.models.block import Block
from app.models.stack_box import StackBox
from app.models.user import User
from app.models.workspace import WorkspaceRole
from app.schemas.block import BlockCreate, BlockRead, BlockReorder, BlockUpdate

router = APIRouter(tags=["blocks"])


def _get_stack_box_or_404(db: Session, stack_box_id: int) -> StackBox:
    stack_box = db.get(StackBox, stack_box_id)
    if stack_box is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="StackBox not found")
    return stack_box


def _get_block_or_404(db: Session, block_id: int) -> Block:
    block = db.get(Block, block_id)
    if block is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Block not found")
    return block


@router.get("/stack-boxes/{stack_box_id}/blocks", response_model=list[BlockRead])
def list_blocks(
    stack_box_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[Block]:
    stack_box = _get_stack_box_or_404(db, stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.viewer)
    return (
        db.query(Block)
        .filter(Block.stack_box_id == stack_box_id)
        .order_by(Block.sort_order)
        .all()
    )


@router.post(
    "/stack-boxes/{stack_box_id}/blocks",
    response_model=BlockRead,
    status_code=status.HTTP_201_CREATED,
)
def create_block(
    stack_box_id: int,
    payload: BlockCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Block:
    stack_box = _get_stack_box_or_404(db, stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.editor)
    data = payload.model_dump()
    block = Block(
        stack_box_id=stack_box_id,
        created_by=current_user.id,
        updated_by=current_user.id,
        **data,
    )
    db.add(block)
    db.commit()
    db.refresh(block)
    return block


@router.patch("/blocks/{block_id}", response_model=BlockRead)
def update_block(
    block_id: int,
    payload: BlockUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Block:
    block = _get_block_or_404(db, block_id)
    stack_box = _get_stack_box_or_404(db, block.stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.editor)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(block, field, value)
    block.updated_by = current_user.id
    db.commit()
    db.refresh(block)
    return block


@router.delete("/blocks/{block_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_block(
    block_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    block = _get_block_or_404(db, block_id)
    stack_box = _get_stack_box_or_404(db, block.stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.editor)
    db.delete(block)
    db.commit()


@router.post("/blocks/{block_id}/reorder", response_model=BlockRead)
def reorder_block(
    block_id: int,
    payload: BlockReorder,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Block:
    block = _get_block_or_404(db, block_id)
    stack_box = _get_stack_box_or_404(db, block.stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.editor)
    block.sort_order = payload.sort_order
    block.updated_by = current_user.id
    db.commit()
    db.refresh(block)
    return block
