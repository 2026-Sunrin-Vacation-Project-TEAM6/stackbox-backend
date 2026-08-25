from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.database import Base, get_db
from app.dependencies import get_current_user
from app.main import app
from app.models.block import Block
from app.models.stack_box import StackBox
from app.models.user import User
from app.models.workspace import Workspace, WorkspaceMember

# The full metadata includes Postgres-only column types (e.g. JSONB on
# CanvasPresence), so only create the tables these tests actually touch
# against the SQLite test engine.
_TEST_TABLES = [
    User.__table__,
    Workspace.__table__,
    WorkspaceMember.__table__,
    StackBox.__table__,
    Block.__table__,
]

_engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
_TestingSessionLocal = sessionmaker(bind=_engine, autoflush=False, autocommit=False)


@pytest.fixture()
def db_session() -> Generator[Session, None, None]:
    Base.metadata.create_all(bind=_engine, tables=_TEST_TABLES)
    session = _TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=_engine, tables=_TEST_TABLES)


@pytest.fixture()
def test_user(db_session: Session) -> User:
    # BigInteger primary keys don't get SQLite's implicit rowid-autoincrement
    # behavior (only a bare Integer PK does), so ids are assigned explicitly
    # throughout these tests instead of relying on autoincrement.
    user = User(id=1, email="owner@example.com", name="Owner", is_active=True)
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture()
def client(db_session: Session, test_user: User) -> Generator[TestClient, None, None]:
    def _override_get_db() -> Generator[Session, None, None]:
        yield db_session

    def _override_get_current_user() -> User:
        return test_user

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()
