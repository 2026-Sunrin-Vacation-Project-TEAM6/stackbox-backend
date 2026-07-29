from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.openapi import API_DESCRIPTION, OPENAPI_TAGS
from app.routers import health

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
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
