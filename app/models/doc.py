from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Float, ForeignKey, LargeBinary, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class DocSnapshot(Base):
    __tablename__ = "doc_snapshots"

    stack_box_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("stack_boxes.id", ondelete="CASCADE"), primary_key=True
    )
    blob: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    state: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    size: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    version: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    created_by: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    updated_by: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DocUpdate(Base):
    __tablename__ = "doc_updates"
    __table_args__ = (UniqueConstraint("stack_box_id", "seq"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    stack_box_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("stack_boxes.id", ondelete="CASCADE"), nullable=False
    )
    blob: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    seq: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_by: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CanvasPresence(Base):
    __tablename__ = "canvas_presence"

    stack_box_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("stack_boxes.id", ondelete="CASCADE"), primary_key=True
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    cursor_x: Mapped[float | None] = mapped_column(Float, nullable=True)
    cursor_y: Mapped[float | None] = mapped_column(Float, nullable=True)
    selection: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    color: Mapped[str | None] = mapped_column(String(32), nullable=True)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
