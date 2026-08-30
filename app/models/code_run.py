from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CodeRun(Base):
    __tablename__ = "code_runs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    block_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("doc_blocks.id", ondelete="CASCADE"), nullable=False
    )
    language: Mapped[str] = mapped_column(String(32), nullable=False)
    stdout: Mapped[str] = mapped_column(Text, nullable=False, default="")
    stderr: Mapped[str] = mapped_column(Text, nullable=False, default="")
    # Compiler stderr for compiled languages (C/C++/Rust) when the submitted
    # code failed to compile. Null for interpreted languages and for runs that
    # compiled successfully — the frontend renders it as a distinct "did not
    # compile" state rather than a generic execution failure.
    compile_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    exit_code: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    duration_ms: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    executed_by: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
