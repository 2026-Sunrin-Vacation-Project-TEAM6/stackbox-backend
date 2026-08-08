from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    email: str = Field(max_length=255)
    password: str = Field(min_length=8, max_length=255)
    name: str = Field(max_length=100)


class LoginRequest(BaseModel):
    email: str = Field(max_length=255)
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
