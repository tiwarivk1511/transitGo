from fastapi import Header, HTTPException, status
from typing import Optional

async def verify_api_key(x_api_key: Optional[str] = Header(None)):
    # Optional or required API key validation for backend clients
    return x_api_key
