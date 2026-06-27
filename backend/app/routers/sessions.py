import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db
from app.models.device_context import DeviceContext
from app.models.exercise import Exercise
from app.models.exercise_set import ExerciseSet
from app.models.session import WorkoutSession
from app.schemas.requests import CreateSessionRequest, UpdateSessionRequest
from app.schemas.workout import WorkoutSessionSchema

router = APIRouter()


async def _get_session_or_404(
    session_id: uuid.UUID, db: AsyncSession
) -> WorkoutSession:
    result = await db.execute(
        select(WorkoutSession)
        .where(WorkoutSession.session_id == str(session_id))
        .options(
            selectinload(WorkoutSession.exercises).selectinload(Exercise.sets)
        )
    )
    session = result.scalars().first()
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.post("/sessions", response_model=WorkoutSessionSchema, status_code=201)
async def create_session(
    body: CreateSessionRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    x_device_uuid: Annotated[str | None, Header()] = None,
) -> WorkoutSessionSchema:
    # device_uuid may come from the request body or the X-Device-UUID header.
    # Normalise to canonical lowercase so it matches how GET endpoints query
    # (FastAPI parses query/path UUIDs to uuid.UUID, whose str() is lowercase).
    raw_device = body.device_uuid or x_device_uuid
    if raw_device is None:
        raise HTTPException(
            status_code=422,
            detail="device_uuid is required (in body or X-Device-UUID header)",
        )
    try:
        device_uuid = str(uuid.UUID(str(raw_device)))
    except ValueError:
        raise HTTPException(status_code=422, detail="invalid device_uuid")

    workout = WorkoutSession(
        device_uuid=str(device_uuid),
        workout_date=body.workout_date,
        source=body.source,
        raw_transcript=body.raw_transcript,
        body_weight_lbs=body.body_weight_lbs,
        workout_type=body.workout_type,
        cardio_notes=body.cardio_notes,
        cardio_activity=body.cardio_activity,
        cardio_distance=body.cardio_distance,
        cardio_distance_unit=body.cardio_distance_unit,
        session_notes=body.session_notes,
        duration_minutes=body.duration_minutes,
    )
    db.add(workout)
    await db.flush()  # get session_id

    for ex_idx, ex_data in enumerate(body.exercises):
        exercise = Exercise(
            session_id=workout.session_id,
            exercise_order=ex_data.exercise_order if ex_data.exercise_order else ex_idx,
            name=ex_data.name,
            equipment=ex_data.equipment,
            muscle_group=ex_data.muscle_group,
            notes=ex_data.notes,
        )
        db.add(exercise)
        await db.flush()

        for set_data in ex_data.sets:
            ex_set = ExerciseSet(
                exercise_id=exercise.exercise_id,
                set_number=set_data.set_number,
                reps=set_data.reps,
                weight=set_data.weight,
                weight_unit=set_data.weight_unit,
                duration_seconds=set_data.duration_seconds,
            )
            db.add(ex_set)

    # UPSERT device_context if body_weight_lbs is provided (atomic, no read-then-write race)
    if body.body_weight_lbs is not None:
        upsert_stmt = (
            pg_insert(DeviceContext)
            .values(
                device_uuid=str(device_uuid),
                last_body_weight_lbs=body.body_weight_lbs,
            )
            .on_conflict_do_update(
                index_elements=[DeviceContext.device_uuid],
                set_={"last_body_weight_lbs": body.body_weight_lbs},
            )
        )
        await db.execute(upsert_stmt)

    await db.flush()

    # Reload with relationships
    return await _get_session_or_404(workout.session_id, db)


@router.get("/sessions", response_model=list[WorkoutSessionSchema])
async def list_sessions(
    device_uuid: Annotated[uuid.UUID, Query(...)],
    start_date: Annotated[date | None, Query()] = None,
    end_date: Annotated[date | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
    db: AsyncSession = Depends(get_db),
) -> list[WorkoutSession]:
    stmt = (
        select(WorkoutSession)
        .where(WorkoutSession.device_uuid == str(device_uuid))
        .options(selectinload(WorkoutSession.exercises).selectinload(Exercise.sets))
        .order_by(WorkoutSession.workout_date.desc())
        .limit(limit)
        .offset(offset)
    )
    if start_date:
        stmt = stmt.where(WorkoutSession.workout_date >= start_date)
    if end_date:
        stmt = stmt.where(WorkoutSession.workout_date <= end_date)

    result = await db.execute(stmt)
    return list(result.scalars().all())


@router.get("/sessions/{session_id}", response_model=WorkoutSessionSchema)
async def get_session(
    session_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> WorkoutSession:
    return await _get_session_or_404(session_id, db)


@router.put("/sessions/{session_id}", response_model=WorkoutSessionSchema)
async def update_session(
    session_id: uuid.UUID,
    body: UpdateSessionRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> WorkoutSession:
    workout = await _get_session_or_404(session_id, db)

    update_data = body.model_dump(exclude_unset=True, exclude={"exercises"})
    for field, value in update_data.items():
        setattr(workout, field, value)

    if body.exercises is not None:
        # Delete existing exercises (cascade will handle sets)
        for ex in list(workout.exercises):
            await db.delete(ex)
        await db.flush()

        # Insert new exercises
        for ex_idx, ex_data in enumerate(body.exercises):
            exercise = Exercise(
                session_id=workout.session_id,
                exercise_order=ex_data.exercise_order if ex_data.exercise_order else ex_idx,
                name=ex_data.name,
                equipment=ex_data.equipment,
                muscle_group=ex_data.muscle_group,
                notes=ex_data.notes,
            )
            db.add(exercise)
            await db.flush()

            for set_data in ex_data.sets:
                ex_set = ExerciseSet(
                    exercise_id=exercise.exercise_id,
                    set_number=set_data.set_number,
                    reps=set_data.reps,
                    weight=set_data.weight,
                    weight_unit=set_data.weight_unit,
                    duration_seconds=set_data.duration_seconds,
                )
                db.add(ex_set)

    await db.flush()
    return await _get_session_or_404(session_id, db)


@router.delete("/sessions/{session_id}", status_code=204)
async def delete_session(
    session_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> None:
    workout = await _get_session_or_404(session_id, db)
    await db.delete(workout)
