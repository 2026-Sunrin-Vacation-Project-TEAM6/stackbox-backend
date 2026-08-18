import io

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from pptx import Presentation
from sqlalchemy.orm import Session

from app.access import require_workspace_role
from app.ai_client import chat as ai_chat
from app.ai_client import complete as ai_complete
from app.database import get_db
from app.dependencies import get_current_user
from app.models.block import Block, BlockType
from app.models.stack_box import StackBox
from app.models.user import User
from app.models.workspace import WorkspaceRole
from app.rate_limit import enforce_rate_limit
from app.schemas.ai import (
    ChatRequest,
    ChatResponse,
    DocToPptRequest,
    DraftRequest,
    DraftResponse,
    FixCodeRequest,
    FixCodeResponse,
    SummarizeRequest,
    SummarizeResponse,
)

router = APIRouter(prefix="/ai", tags=["ai"])

# Every /ai/* call is billed against our OpenAI key regardless of which user
# triggers it, so cap usage per user rather than leaving it unbounded.
_AI_RATE_LIMIT = 20
_AI_RATE_WINDOW_SECONDS = 3600

_CHAT_SYSTEM_PROMPT = (
    "당신은 StackBox 문서 작성을 돕는 어시스턴트입니다. 사용자 요청에 협조적이고 "
    "간결하게 답하세요."
)


def _enforce_ai_rate_limit(current_user: User = Depends(get_current_user)) -> None:
    enforce_rate_limit(f"ai:{current_user.id}", _AI_RATE_LIMIT, _AI_RATE_WINDOW_SECONDS)


def _get_stack_box_or_404(db: Session, stack_box_id: int) -> StackBox:
    stack_box = db.get(StackBox, stack_box_id)
    if stack_box is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="StackBox not found")
    return stack_box


@router.post("/summarize", response_model=SummarizeResponse)
def summarize(
    payload: SummarizeRequest,
    current_user: User = Depends(get_current_user),
    _: None = Depends(_enforce_ai_rate_limit),
) -> SummarizeResponse:
    summary = ai_complete(
        "당신은 문서를 간결하게 요약하는 어시스턴트입니다. 핵심만 3~5문장으로 요약하세요.",
        payload.text,
    )
    return SummarizeResponse(summary=summary)


@router.post("/fix-code", response_model=FixCodeResponse)
def fix_code(
    payload: FixCodeRequest,
    current_user: User = Depends(get_current_user),
    _: None = Depends(_enforce_ai_rate_limit),
) -> FixCodeResponse:
    instructions = payload.instructions or "버그를 찾아 수정하고 개선하세요."
    language_hint = f" (언어: {payload.language})" if payload.language else ""
    system_prompt = (
        "당신은 숙련된 소프트웨어 엔지니어입니다. 아래 형식을 정확히 지켜 응답하세요:\n"
        "```\n<수정된 코드>\n```\n설명: <한두 문장 설명>"
    )
    user_prompt = f"지시사항: {instructions}{language_hint}\n\n코드:\n{payload.code}"
    raw = ai_complete(system_prompt, user_prompt)

    fixed_code = raw
    explanation = ""
    if "```" in raw:
        parts = raw.split("```")
        if len(parts) >= 2:
            code_block = parts[1]
            fixed_code = code_block.split("\n", 1)[-1] if "\n" in code_block else code_block
            remainder = "```".join(parts[2:])
            explanation = remainder.replace("설명:", "").strip()

    return FixCodeResponse(fixed_code=fixed_code.strip(), explanation=explanation)


@router.post("/draft", response_model=DraftResponse)
def draft(
    payload: DraftRequest,
    current_user: User = Depends(get_current_user),
    _: None = Depends(_enforce_ai_rate_limit),
) -> DraftResponse:
    text = ai_complete(
        "당신은 문서 초안을 작성하는 어시스턴트입니다. 마크다운 형식으로 초안을 작성하세요.",
        payload.prompt,
    )
    return DraftResponse(draft=text)


@router.post("/chat", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
    current_user: User = Depends(get_current_user),
    _: None = Depends(_enforce_ai_rate_limit),
) -> ChatResponse:
    # payload.messages can only carry "user"/"assistant" roles (see ChatMessage),
    # so the system prompt below is always the first and only "system" message
    # sent to OpenAI.
    messages = [{"role": "system", "content": _CHAT_SYSTEM_PROMPT}]
    messages += [{"role": m.role, "content": m.content} for m in payload.messages]
    reply = ai_chat(messages)
    return ChatResponse(reply=reply)


@router.post("/doc-to-ppt")
def doc_to_ppt(
    payload: DocToPptRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    _: None = Depends(_enforce_ai_rate_limit),
) -> StreamingResponse:
    stack_box = _get_stack_box_or_404(db, payload.stack_box_id)
    require_workspace_role(db, stack_box.workspace_id, current_user, WorkspaceRole.viewer)

    blocks = (
        db.query(Block)
        .filter(Block.stack_box_id == stack_box.id, Block.type == BlockType.markdown)
        .order_by(Block.sort_order)
        .all()
    )
    document_text = "\n\n".join(block.content for block in blocks) or stack_box.description

    outline = ai_complete(
        "당신은 문서를 PPT 슬라이드 개요로 변환하는 어시스턴트입니다. "
        "각 슬라이드는 '# ' 로 시작하는 제목 한 줄과, 그 아래 '- ' 로 시작하는 bullet point 여러 줄로 구성하세요. "
        "다른 설명 없이 개요만 출력하세요.",
        document_text,
    )

    presentation = Presentation()
    title_layout = presentation.slide_layouts[0]
    bullet_layout = presentation.slide_layouts[1]

    title_slide = presentation.slides.add_slide(title_layout)
    title_slide.shapes.title.text = stack_box.name

    current_slide = None
    for line in outline.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            current_slide = presentation.slides.add_slide(bullet_layout)
            current_slide.shapes.title.text = stripped.lstrip("#").strip()
        elif stripped.startswith("-"):
            if current_slide is None:
                current_slide = presentation.slides.add_slide(bullet_layout)
            body = current_slide.placeholders[1].text_frame
            if body.text:
                body.add_paragraph().text = stripped.lstrip("-").strip()
            else:
                body.text = stripped.lstrip("-").strip()

    buffer = io.BytesIO()
    presentation.save(buffer)
    buffer.seek(0)

    filename = f"{stack_box.name}.pptx"
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.presentationml.presentation",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
