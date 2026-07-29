from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get(
    "/health",
    summary="헬스체크",
    description="API 서버가 정상 응답하는지 확인합니다.",
    response_description="서버 상태",
)
def health_check() -> dict[str, str]:
    return {"status": "ok"}
