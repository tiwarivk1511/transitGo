import time
import logging
from fastapi import Request

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TransitGo")

async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    logger.info(f"Path: {request.url.path} | Method: {request.method} | Status: {response.status_code} | Duration: {duration:.4f}s")
    return response
