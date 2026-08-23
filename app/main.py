from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.openapi import API_DESCRIPTION, OPENAPI_TAGS
from app.routers import (
    ai,
    auth,
    blocks,
    code_exec,
    github,
    health,
    reactions,
    stack_boxes,
    users,
    workspaces,
)

app = FastAPI(
    title="StackBox API",
    description=API_DESCRIPTION,
    version="0.1.0",
    openapi_tags=OPENAPI_TAGS,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:3002",
        "http://127.0.0.1:3002",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(workspaces.router)
app.include_router(stack_boxes.router)
app.include_router(blocks.router)
app.include_router(code_exec.router)
app.include_router(github.router)
app.include_router(ai.router)
app.include_router(reactions.router)
