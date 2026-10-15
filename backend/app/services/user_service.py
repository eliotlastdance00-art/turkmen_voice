"""User accounts (anonymous, device based) + gamification profiles."""

from __future__ import annotations

import logging
import random
import re
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException

from app.core.security import legacy_user_id, new_token
from app.domain.entities.recording import User, level_for_points
from app.repositories.sqlite_recording_repository import SqliteRecordingRepository
from app.repositories.sqlite_user_repository import SqliteUserRepository
from app.services import points

log = logging.getLogger("turkmen_ses.user")

NAME_RE = re.compile(r"^[^\d\W]{2,24}(?:[ \-][^\d\W]{2,24})*$", re.UNICODE)
_ADJECTIVES = ("Şadyýan", "Gaýratly", "Mähirli", "Akylly", "Batyr", "Ýiti", "Sabyrly", "Nurana", "Garagum", "Köpetdag")
_NOUNS = ("Ses", "Bagşy", "Dutar", "Ýyldyz", "Gül", "At", "Ýol", "Kitap", "Deňiz", "Şemal")


class UserService:
    def __init__(self, users: SqliteUserRepository, recordings: SqliteRecordingRepository):
        self.users = users
        self.recordings = recordings

    # ------------------------------------------------------------------ account
    def register(
        self,
        device_id: str,
        display_name: str | None = None,
        avatar_seed: int | None = None,
        consent_type: str = "dataset",
    ) -> tuple[User, str]:
        device_id = device_id.strip()[:80]
        if len(device_id) < 6:
            raise HTTPException(422, "device_id gysga")
        if consent_type not in {"dataset", "internal"}:
            raise HTTPException(422, "consent_type nädogry")

        clean_name = self._clean_name(display_name) if display_name else None
        existing = self.users.get_by_device(device_id)
        if existing is not None:
            updated = self.users.update_profile(
                existing.id,
                display_name=clean_name if clean_name and clean_name != existing.display_name else None,
                avatar_seed=avatar_seed,
                consent_type=consent_type,
            )
            self.users.touch(existing.id)
            user = updated or existing
            return user, self.token_for(user)

        name = clean_name or self._suggest_name()
        user = self.users.create(
            device_id=device_id,
            display_name=name,
            avatar_seed=avatar_seed if avatar_seed is not None else random.randint(0, 9999),
            consent_type=consent_type,
            token=new_token(),
        )
        return user, self.token_for(user)

    def token_for(self, user: User) -> str:
        """Return the account token, creating and storing it when missing.

        The token is persisted in ``users.token`` so a redeployed server (or a
        second instance) can resolve the same account again.  Accounts created
        by the first MVP have no token yet — they get one lazily here.
        """
        if user.token:
            return user.token
        candidate = new_token()
        updated = self.users.set_token(user.id, candidate)
        if updated is not None:
            return updated.token or candidate
        return candidate

    def resolve_token(self, token: str | None) -> User | None:
        if not token:
            return None
        cleaned = token.strip()
        user = self.users.get_by_token(cleaned)
        if user is not None:
            return user
        # backwards compatibility: the first APK sent ``tk_<user_id>``
        return self.users.get(legacy_user_id(cleaned))

    def profile(self, user: User) -> dict:
        recordings = self.recordings.list(user_id=user.id, limit=1000)
        approved = [item for item in recordings if item.status.value == "approved"]
        seconds = sum(item.duration_ms for item in recordings) // 1000
        scored = [item.community_score for item in approved if item.community_score is not None]
        avg_quality = round(sum(scored) / len(scored), 2) if scored else None
        level = level_for_points(user.points)
        return {
            "id": user.id,
            "display_name": user.display_name,
            "avatar_seed": user.avatar_seed,
            "language": user.language,
            "consent_type": user.consent_type,
            "points": user.points,
            "level": level,
            "created_at": user.created_at,
            "last_seen_at": user.last_seen_at,
            "stats": {
                "recordings": len(recordings),
                "approved": len(approved),
                "pending": len([item for item in recordings if item.status.value == "pending"]),
                "rejected": len([item for item in recordings if item.status.value == "rejected"]),
                "seconds": seconds,
                "avg_quality": avg_quality,
                "ratings_given": user.ratings_given,
                "ratings_received": user.ratings_received,
            },
            "streak_days": self.streak(user.id),
            "rank": self.users.rank_of(user.id),
            "badges": self.badges(user, recordings),
        }

    def public_profile(self, user_id: str) -> dict:
        user = self.users.get(user_id)
        if user is None:
            raise HTTPException(404, "Ulanyjy tapylmady")
        profile = self.profile(user)
        profile.pop("consent_type", None)
        return profile

    def update(self, user: User, display_name: str | None = None, avatar_seed: int | None = None, consent_type: str | None = None) -> User:
        if display_name is not None:
            display_name = self._clean_name(display_name)
        if consent_type is not None and consent_type not in {"dataset", "internal"}:
            raise HTTPException(422, "consent_type nädogry")
        updated = self.users.update_profile(user.id, display_name, avatar_seed, consent_type)
        if updated is None:
            raise HTTPException(404, "Ulanyjy tapylmady")
        return updated

    def leaderboard(self, limit: int = 20, period: str = "all", me: User | None = None) -> dict:
        period_days = {"all": None, "week": 7, "month": 30}.get(period, None)
        board = self.users.leaderboard(limit=limit, period_days=period_days)
        for entry in board:
            entry["is_me"] = bool(me and entry["user_id"] == me.id)
        my_entry = None
        if me is not None:
            my_entry = next((entry for entry in board if entry["is_me"]), None)
            if my_entry is None:
                my_rank = self.users.rank_of(me.id)
                my_ranked = next((item for item in self.users.leaderboard(limit=100) if item["user_id"] == me.id), None)
                if my_ranked is not None:
                    my_ranked["is_me"] = True
                    my_ranked["rank"] = my_rank or my_ranked["rank"]
                    my_entry = my_ranked
        return {"period": period, "entries": board, "me": my_entry, "levels": self.users.levels()}

    def streak(self, user_id: str) -> int:
        days = set(self.users.active_days(user_id))
        if not days:
            return 0
        today = datetime.now(timezone.utc).date()
        streak = 0
        cursor = today
        if today.isoformat() not in days:
            cursor = today - timedelta(days=1)
        while cursor.isoformat() in days:
            streak += 1
            cursor -= timedelta(days=1)
        return streak

    def badges(self, user: User, recordings=None) -> list[dict]:
        recordings = recordings if recordings is not None else []
        approved = [item for item in recordings if item.status.value == "approved"]
        seconds = sum(item.duration_ms for item in recordings) // 1000
        badges = [
            {"id": "first_take", "name": "Ilkinji ses", "icon": "mic", "earned": len(recordings) >= 1},
            {"id": "ten_takes", "name": "On ýazgy", "icon": "library", "earned": len(recordings) >= 10},
            {"id": "fifty_takes", "name": "Ellilik ýazgy", "icon": "star", "earned": len(recordings) >= 50},
            {"id": "one_hour", "name": "Bir sagat ses", "icon": "timer", "earned": seconds >= 3600},
            {"id": "checker", "name": "Barlaýjy", "icon": "verified", "earned": user.ratings_given >= 25},
            {"id": "curator", "name": "Hil hünärmeni", "icon": "workspace_premium", "earned": user.ratings_given >= 100},
            {"id": "high_quality", "name": "Arassa ses", "icon": "graphic_eq", "earned": bool(approved) and all(
                (item.community_score or 0) >= 4 for item in approved[:5] if item.community_score is not None
            ) and len([item for item in approved if item.community_score is not None]) >= 5},
            {"id": "streak_7", "name": "Ýedi günlük yhlas", "icon": "local_fire_department", "earned": self.streak(user.id) >= 7},
        ]
        return badges

    # ------------------------------------------------------------------ helpers
    @staticmethod
    def _clean_name(value: str) -> str:
        candidate = " ".join(value.split())[:24]
        if len(candidate) < 2:
            raise HTTPException(422, "At iň az 2 harpdan ybarat bolmaly")
        banned = {"admin", "administrator", "moderator", "turkmen ses"}
        if candidate.lower() in banned:
            raise HTTPException(422, "Bu at ulanyp bolmaýar")
        return candidate

    @staticmethod
    def _suggest_name() -> str:
        return f"{random.choice(_ADJECTIVES)} {random.choice(_NOUNS)} {random.randint(10, 99)}"

    def award_streak_bonus(self, user: User) -> int:
        streak = self.streak(user.id)
        if streak and streak % 3 == 0:
            return self.users.add_points(user.id, points.DAILY_STREAK, "daily_streak", f"{streak} gün")
        return user.points
