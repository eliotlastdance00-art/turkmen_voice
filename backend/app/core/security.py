"""Auth helpers.

The MVP uses anonymous, device based accounts:

* the app generates a uuid ``device_id`` on first launch,
* ``POST /users/register`` maps it to a ``user_id`` and returns ``tk_<user_id>``,
* every later call sends ``Authorization: Bearer tk_<user_id>``
  (``X-Device-Id`` also works, so old APKs keep uploading).

Admin endpoints require the ``ADMIN_TOKEN`` environment variable.  When it
is not configured the service runs in an *open dev mode* and logs a warning
— never ship that to production.
"""

from __future__ import annotations

import logging

from fastapi import Header, HTTPException, status

from app.core.config import settings

log = logging.getLogger("turkmen_ses.security")


def admin_guard(
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
    authorization: str | None = Header(default=None),
) -> None:
    if settings.admin_open:
        return
    token = x_admin_token
    if not token and authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:]
    if token != settings.admin_token:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Admin token nädogry")


def bearer_token(authorization: str | None) -> str | None:
    if authorization and authorization.lower().startswith("bearer "):
        return authorization[7:].strip()
    return None


def warn_if_open_mode() -> None:
    if settings.admin_open:
        log.warning(
            "ADMIN_TOKEN is empty -> /admin is open. Set ADMIN_TOKEN before exposing this API."
        )
