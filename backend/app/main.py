from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.db.sqlite import init_database
from app.routers import admin, admin_audio, health, recordings, sentences


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_database()
    yield


app = FastAPI(title=settings.app_name, version=settings.version, lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['*'], allow_headers=['*'])
app.include_router(health.router, prefix='/api/v1')
app.include_router(sentences.router, prefix='/api/v1')
app.include_router(recordings.router, prefix='/api/v1')
app.include_router(admin.router, prefix='/api/v1')
app.include_router(admin_audio.router, prefix='/api/v1')
app.mount('/admin', StaticFiles(directory='app/static/admin', html=True), name='admin')
