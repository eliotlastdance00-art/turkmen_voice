"""Point rules — the single source of truth for the gamification system."""

RECORDING_UPLOADED = 2
RECORDING_APPROVED = 10
RECORDING_HIGH_QUALITY = 8
RATING_GIVEN = 2
RATING_CAREFUL = 1  # mismatch reported with a reason
DAILY_STREAK = 3

KIND_LABELS: dict[str, str] = {
    "recording_uploaded": "Ses ýazgy ýüklendi",
    "recording_approved": "Ýazgy kabul edildi",
    "recording_reverted": "Ýazgy ret edildi",
    "recording_high_quality": "Ýokary hilli ýazgy",
    "rating_given": "Baha berildi",
    "rating_careful": "Jikme-jik barlag",
    "daily_streak": "Günlük işjeňlik",
    "admin_bonus": "Admin bonusy",
}
