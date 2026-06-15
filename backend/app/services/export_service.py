import io
from decimal import Decimal

import pandas as pd

from app.models.session import WorkoutSession


def build_dataframe(sessions: list[WorkoutSession]) -> pd.DataFrame:
    """Flatten sessions + exercises + sets into a single DataFrame."""
    rows = []
    for session in sessions:
        for exercise in session.exercises:
            for s in exercise.sets:
                rows.append(
                    {
                        "date": session.workout_date,
                        "workout_type": session.workout_type,
                        "exercise_name": exercise.name,
                        "equipment": exercise.equipment,
                        "muscle_group": exercise.muscle_group,
                        "set_number": s.set_number,
                        "reps": s.reps,
                        "weight": float(s.weight) if s.weight is not None else None,
                        "weight_unit": s.weight_unit,
                        "duration_seconds": s.duration_seconds,
                        "body_weight_lbs": (
                            float(session.body_weight_lbs)
                            if session.body_weight_lbs is not None
                            else None
                        ),
                    }
                )
    if not rows:
        return pd.DataFrame(
            columns=[
                "date",
                "workout_type",
                "exercise_name",
                "equipment",
                "muscle_group",
                "set_number",
                "reps",
                "weight",
                "weight_unit",
                "duration_seconds",
                "body_weight_lbs",
            ]
        )
    return pd.DataFrame(rows)


def export_csv(sessions: list[WorkoutSession]) -> bytes:
    df = build_dataframe(sessions)
    return df.to_csv(index=False).encode("utf-8")


def export_xlsx(sessions: list[WorkoutSession]) -> bytes:
    df = build_dataframe(sessions)
    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="Workouts")
    return buf.getvalue()
