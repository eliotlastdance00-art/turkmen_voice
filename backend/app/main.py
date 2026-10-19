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

# Production howpsuzlyk middleware.
# PUBLIC_BASE_URL ýa-da ALLOWED_HOSTS goýulmadýan bolsa, ähli host kabul edilýär
# (FastAPI Cloud-yň içerki health probe-y hem işlemeli!).
def _trusted_hosts() -> list[str]:
    if not settings.public_base_url and not settings.allowed_hosts:
        return ["*"]

    hosts = {"localhost", "127.0.0.1", "testserver"}
    for item in (*settings.allowed_hosts, settings.public_base_url):
        host = item.split("//")[-1].split("/")[0].strip()
        if host:
            hosts.add(host)
    return sorted(hosts)


app.add_middleware(TrustedHostMiddleware, allowed_hosts=_trusted_hosts())

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)


@app.middleware("http")
async def security_headers(request, call_next):
    """Protect the admin UI and its authenticated API responses in browsers."""
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("Referrer-Policy", "no-referrer")

    path = request.url.path
    is_admin_response = (
        path == "/admin"
        or path.startswith("/admin/")
        or path.startswith(f"{settings.api_prefix}/admin/")
    )
    if is_admin_response:
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        response.headers["Content-Security-Policy"] = (
            "default-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; "
            "script-src 'self'; script-src-attr 'none'; style-src 'self'; style-src-attr 'none'; connect-src 'self'; "
            "img-src 'self' data:; media-src 'self'; font-src 'self'; object-src 'none'; "
            "manifest-src 'self'"
        )
    return response


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
