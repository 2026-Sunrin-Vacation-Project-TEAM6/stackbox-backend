import enum
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class StackBoxType(str, enum.Enum):
    folder = "folder"
    page = "page"
    canvas = "canvas"
    edgeless = "edgeless"


class StackBox(Base):
    __tablename__ = "stack_boxes"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    workspace_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False
    )
    parent_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("stack_boxes.id", ondelete="CASCADE"), nullable=True
    )
    type: Mapped[StackBoxType] = mapped_column(
        Enum(StackBoxType, name="stack_box_type"), nullable=False, default=StackBoxType.folder
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    icon: Mapped[str | None] = mapped_column(String(64), nullable=True)
    cover_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_by: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    updated_by: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
