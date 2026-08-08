import base64

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.doc import CanvasPresence, DocSnapshot, DocUpdate
from app.models.stack_box import StackBox
from app.schemas.doc import (
    CanvasPresenceRead,
    DocSnapshotRead,
    DocSnapshotUpsert,
    DocUpdateRead,
)
from app.schemas.stack_box import StackBoxCreate, StackBoxRead, StackBoxUpdate

router = APIRouter(prefix="/stack-boxes", tags=["stack-boxes"])


def _get_stack_box_or_404(db: Session, stack_box_id: int) -> StackBox:
    stack_box = db.get(StackBox, stack_box_id)
    if stack_box is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="StackBox not found")
    return stack_box


@router.post("", response_model=StackBoxRead, status_code=status.HTTP_201_CREATED)
def create_stack_box(payload: StackBoxCreate, db: Session = Depends(get_db)) -> StackBox:
    stack_box = StackBox(**payload.model_dump())
    db.add(stack_box)
    db.commit()
    db.refresh(stack_box)
    return stack_box


@router.get("", response_model=list[StackBoxRead])
def list_stack_boxes(
    workspace_id: int,
    parent_id: int | None = None,
    db: Session = Depends(get_db),
) -> list[StackBox]:
    query = db.query(StackBox).filter(StackBox.workspace_id == workspace_id)
    if parent_id is not None:
        query = query.filter(StackBox.parent_id == parent_id)
    return query.order_by(StackBox.sort_order).all()


@router.get("/{stack_box_id}", response_model=StackBoxRead)
def get_stack_box(stack_box_id: int, db: Session = Depends(get_db)) -> StackBox:
    return _get_stack_box_or_404(db, stack_box_id)


@router.patch("/{stack_box_id}", response_model=StackBoxRead)
def update_stack_box(
    stack_box_id: int, payload: StackBoxUpdate, db: Session = Depends(get_db)
) -> StackBox:
    stack_box = _get_stack_box_or_404(db, stack_box_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(stack_box, field, value)
    db.commit()
    db.refresh(stack_box)
    return stack_box


@router.delete("/{stack_box_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_stack_box(stack_box_id: int, db: Session = Depends(get_db)) -> None:
    stack_box = _get_stack_box_or_404(db, stack_box_id)
    db.delete(stack_box)
    db.commit()


def _encode(data: bytes | None) -> str | None:
    return base64.b64encode(data).decode("ascii") if data is not None else None


def _snapshot_to_read(snapshot: DocSnapshot) -> DocSnapshotRead:
    return DocSnapshotRead(
        stack_box_id=snapshot.stack_box_id,
        blob=_encode(snapshot.blob),
        state=_encode(snapshot.state),
        size=snapshot.size,
        version=snapshot.version,
        created_by=snapshot.created_by,
        updated_by=snapshot.updated_by,
        created_at=snapshot.created_at,
        updated_at=snapshot.updated_at,
    )


@router.get("/{stack_box_id}/snapshot", response_model=DocSnapshotRead)
def get_snapshot(stack_box_id: int, db: Session = Depends(get_db)) -> DocSnapshotRead:
    _get_stack_box_or_404(db, stack_box_id)
    snapshot = db.get(DocSnapshot, stack_box_id)
    if snapshot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Snapshot not found")
    return _snapshot_to_read(snapshot)


@router.put("/{stack_box_id}/snapshot", response_model=DocSnapshotRead)
def upsert_snapshot(
    stack_box_id: int, payload: DocSnapshotUpsert, db: Session = Depends(get_db)
) -> DocSnapshotRead:
    _get_stack_box_or_404(db, stack_box_id)
    blob = base64.b64decode(payload.blob)
    state = base64.b64decode(payload.state) if payload.state is not None else None

    snapshot = db.get(DocSnapshot, stack_box_id)
    if snapshot is None:
        snapshot = DocSnapshot(
            stack_box_id=stack_box_id,
            blob=blob,
            state=state,
            size=len(blob),
            version=0,
            created_by=payload.created_by,
            updated_by=payload.updated_by,
        )
        db.add(snapshot)
    else:
        snapshot.blob = blob
        snapshot.state = state
        snapshot.size = len(blob)
        snapshot.version += 1
        snapshot.updated_by = payload.updated_by

    db.commit()
    db.refresh(snapshot)
    return _snapshot_to_read(snapshot)


@router.get("/{stack_box_id}/updates", response_model=list[DocUpdateRead])
def list_doc_updates(
    stack_box_id: int,
    since_seq: int = 0,
    limit: int = 500,
    db: Session = Depends(get_db),
) -> list[DocUpdateRead]:
    _get_stack_box_or_404(db, stack_box_id)
    updates = (
        db.query(DocUpdate)
        .filter(DocUpdate.stack_box_id == stack_box_id, DocUpdate.seq > since_seq)
        .order_by(DocUpdate.seq)
        .limit(limit)
        .all()
    )
    return [
        DocUpdateRead(
            id=u.id,
            stack_box_id=u.stack_box_id,
            blob=_encode(u.blob),
            seq=u.seq,
            created_by=u.created_by,
            created_at=u.created_at,
        )
        for u in updates
    ]


@router.get("/{stack_box_id}/presence", response_model=list[CanvasPresenceRead])
def list_presence(stack_box_id: int, db: Session = Depends(get_db)) -> list[CanvasPresence]:
    _get_stack_box_or_404(db, stack_box_id)
    return (
        db.query(CanvasPresence)
        .filter(CanvasPresence.stack_box_id == stack_box_id)
        .all()
    )
