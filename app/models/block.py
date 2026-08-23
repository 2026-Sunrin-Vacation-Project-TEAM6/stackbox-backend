import enum
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Double, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class BlockType(str, enum.Enum):
    markdown = "markdown"
    code = "code"


class Block(Base):
    __tablename__ = "doc_blocks"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    stack_box_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("stack_boxes.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[BlockType] = mapped_column(
        Enum(BlockType, name="block_type"), nullable=False, default=BlockType.markdown
    )
    language: Mapped[str | None] = mapped_column(String(32), nullable=True)
    content: Mapped[str] = mapped_column(Text, nullable=False, default="")
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    pos_x: Mapped[float | None] = mapped_column(Double, nullable=True)
    pos_y: Mapped[float | None] = mapped_column(Double, nullable=True)
    width: Mapped[float | None] = mapped_column(Double, nullable=True)
    height: Mapped[float | None] = mapped_column(Double, nullable=True)
    created_by: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    updated_by: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
