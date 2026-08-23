API_DESCRIPTION = """
StackBox API 서버입니다.

## 문서

- **Swagger UI**: `/docs`
- **ReDoc**: `/redoc`
- **OpenAPI JSON**: `/openapi.json`
"""

OPENAPI_TAGS = [
    {
        "name": "health",
        "description": "서버 상태 확인",
    },
    {
        "name": "auth",
        "description": "회원가입, 로그인, 토큰 갱신 및 로그아웃",
    },
    {
        "name": "users",
        "description": "사용자 CRUD",
    },
    {
        "name": "workspaces",
        "description": "워크스페이스 및 멤버 CRUD",
    },
    {
        "name": "stack-boxes",
        "description": "StackBox(폴더/페이지/캔버스) CRUD",
    },
]
