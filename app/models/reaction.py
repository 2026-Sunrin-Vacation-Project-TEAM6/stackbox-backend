from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Reaction(Base):
    __tablename__ = "reactions"
    __table_args__ = (UniqueConstraint("stack_box_id", "user_id", "emoji_code"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    stack_box_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("stack_boxes.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    emoji_code: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
