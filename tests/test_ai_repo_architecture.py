from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.block import Block, BlockType
from app.models.stack_box import StackBox, StackBoxType
from app.models.user import User
from app.models.workspace import Workspace
from app.routers import ai as ai_router


def _create_workspace(
    db_session: Session, owner: User, workspace_id: int = 1, slug: str = "acme"
) -> Workspace:
    workspace = Workspace(id=workspace_id, name="Acme", slug=slug, owner_id=owner.id)
    db_session.add(workspace)
    db_session.commit()
    db_session.refresh(workspace)
    return workspace


def test_repo_architecture_returns_ai_analysis_for_workspace_member(
    client: TestClient, db_session: Session, test_user: User, monkeypatch
) -> None:
    workspace = _create_workspace(db_session, test_user)

    folder = StackBox(id=1, workspace_id=workspace.id, type=StackBoxType.folder, name="Docs")
    db_session.add(folder)
    db_session.commit()
    db_session.refresh(folder)

    page = StackBox(
        id=2,
        workspace_id=workspace.id,
        parent_id=folder.id,
        type=StackBoxType.page,
        name="Overview",
    )
    db_session.add(page)
    db_session.commit()
    db_session.refresh(page)

    db_session.add(Block(id=1, stack_box_id=page.id, type=BlockType.markdown, content="hello"))
    db_session.add(Block(id=2, stack_box_id=page.id, type=BlockType.code, content="print(1)"))
    db_session.commit()

    captured: dict[str, str] = {}

    def fake_complete(system_prompt: str, user_prompt: str) -> str:
        captured["system_prompt"] = system_prompt
        captured["user_prompt"] = user_prompt
        return "mocked architecture analysis"

    monkeypatch.setattr(ai_router, "ai_complete", fake_complete)
    client.app.dependency_overrides[ai_router._enforce_ai_rate_limit] = lambda: None

    response = client.post("/ai/repo-architecture", json={"workspace_id": workspace.id})

    assert response.status_code == 200
    assert response.json() == {"analysis": "mocked architecture analysis"}

    assert "Docs" in captured["user_prompt"]
    assert "Overview" in captured["user_prompt"]
    assert "markdown 블록 1개" in captured["user_prompt"]
    assert "code 블록 1개" in captured["user_prompt"]


def test_repo_architecture_rejects_non_member(
    client: TestClient, db_session: Session, test_user: User, monkeypatch
) -> None:
    other_owner = User(id=2, email="other@example.com", name="Other", is_active=True)
    db_session.add(other_owner)
    db_session.commit()
    db_session.refresh(other_owner)

    workspace = _create_workspace(db_session, other_owner, workspace_id=2, slug="other-workspace")

    monkeypatch.setattr(
        ai_router,
        "ai_complete",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(AssertionError("should not call AI")),
    )
    client.app.dependency_overrides[ai_router._enforce_ai_rate_limit] = lambda: None

    response = client.post("/ai/repo-architecture", json={"workspace_id": workspace.id})

    assert response.status_code == 403


def test_repo_architecture_unknown_workspace_returns_404(
    client: TestClient, monkeypatch
) -> None:
    monkeypatch.setattr(
        ai_router,
        "ai_complete",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(AssertionError("should not call AI")),
    )
    client.app.dependency_overrides[ai_router._enforce_ai_rate_limit] = lambda: None

    response = client.post("/ai/repo-architecture", json={"workspace_id": 999})

    assert response.status_code == 404
