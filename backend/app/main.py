from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.core.security import warn_if_open_mode
from app.db.sqlite import init_database
from app.routers import admin, health, leaderboard, ratings, recordings, sentences, stats, users


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_database()
    warn_if_open_mode()
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    description=(
        "Türkmençe ses maglumat ýygnama API. Ses 16 kHz mono PCM16 WAV görnüşine "
        "getirilýär we Whisper fine-tuning üçin taýýar eksport berilýär."
    ),
    lifespan=lifespan,
)

# Production howpsuzlyk middleware
allowed_hosts = ["*"] if not settings.public_base_url else [settings.public_base_url.replace("https://", "").replace("http://", "").split("/")[0]]
app.add_middleware(TrustedHostMiddleware, allowed_hosts=allowed_hosts)

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

app.include_router(health.router, prefix=settings.api_prefix)
app.include_router(sentences.router, prefix=settings.api_prefix)
app.include_router(recordings.router, prefix=settings.api_prefix)
app.include_router(ratings.router, prefix=settings.api_prefix)
app.include_router(users.router, prefix=settings.api_prefix)
app.include_router(leaderboard.router, prefix=settings.api_prefix)
app.include_router(stats.router, prefix=settings.api_prefix)
app.include_router(admin.router, prefix=settings.api_prefix)

# Static fayllar üçin ýol (docker we lokal işlemek üçin ýörite)
STATIC_DIR = Path(__file__).parent / "static" / "admin"
app.mount("/admin", StaticFiles(directory=str(STATIC_DIR), html=True), name="admin")


@app.get("/", include_in_schema=False)
def root() -> RedirectResponse:
    return RedirectResponse("/admin/")
