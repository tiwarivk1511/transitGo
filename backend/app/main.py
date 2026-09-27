import sys
import asyncio

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import (
    trains,
    stations,
    pnr,
    fares,
    schedules,
    traffic,
)

from app.providers.ntes.client import NtesClient
from app.router.data_router import DataRouter


# ---------------------------------------------------------------------------
# Windows + Playwright
# ---------------------------------------------------------------------------
#
# Playwright uses subprocesses internally. On Windows it requires the
# Proactor event loop.
#
# IMPORTANT:
# Do not use:
#
#     uvicorn app.main:app --reload
#
# together with async Playwright on Windows.
#
# Use:
#
#     uvicorn app.main:app
#
# ---------------------------------------------------------------------------

if sys.platform == "win32":
    try:
        asyncio.set_event_loop_policy(
            asyncio.WindowsProactorEventLoopPolicy()
        )
    except AttributeError:
        # Safety fallback for environments where the policy is unavailable.
        pass


# ---------------------------------------------------------------------------
# NTES Client
# ---------------------------------------------------------------------------

ntes_client = NtesClient(
    base_url="https://enquiry.indianrail.gov.in/ntes/",
    headless=True,
)


# ---------------------------------------------------------------------------
# Data Router
# ---------------------------------------------------------------------------

data_router = DataRouter(
    ntes=ntes_client,
)


# ---------------------------------------------------------------------------
# FastAPI Lifespan
# ---------------------------------------------------------------------------
#
# Playwright is intentionally NOT started here.
#
# The NTES session should be started lazily when an actual NTES request
# requires it.
#
# This prevents FastAPI startup from failing just because the browser
# process cannot be created.
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):

    # Application startup
    print("TransitGo backend starting...")

    yield

    # Application shutdown
    print("TransitGo backend shutting down...")

    try:
        await ntes_client.close()
    except Exception as exc:
        print(f"NTES shutdown warning: {exc}")


# ---------------------------------------------------------------------------
# FastAPI Application
# ---------------------------------------------------------------------------

app = FastAPI(
    title="TransitGo Railway Data Platform",
    version="1.0.0",
    description=(
        "TransitGo backend using public railway "
        "web sources and provider adapters."
    ),
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# API Routers
# ---------------------------------------------------------------------------

app.include_router(
    trains.router,
)

app.include_router(
    stations.router,
)

app.include_router(
    pnr.router,
)

app.include_router(
    fares.router,
)

app.include_router(
    schedules.router,
)

app.include_router(
    traffic.router,
)


# ---------------------------------------------------------------------------
# Root
# ---------------------------------------------------------------------------

@app.get("/")
async def root():

    return {
        "name": "TransitGo",
        "status": "online",
        "architecture": (
            "web-source adapters + caching"
        ),
    }


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():

    return {
        "status": "ok",
    }