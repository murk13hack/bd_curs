"""CRUD тем."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import Topic
from app.schemas.topic import TopicCreate, TopicRead, TopicUpdate

router = APIRouter(prefix="/topics", tags=["topics"])


@router.get("", response_model=list[TopicRead], summary="Список тем")
async def list_topics(session: SessionDep, user_id: UserIdDep) -> list[Topic]:
    res = await session.execute(
        select(Topic).where(Topic.user_id == user_id).order_by(Topic.name)
    )
    return list(res.scalars())


@router.post(
    "", response_model=TopicRead, status_code=status.HTTP_201_CREATED, summary="Создать тему"
)
async def create_topic(payload: TopicCreate, session: SessionDep, user_id: UserIdDep) -> Topic:
    topic = Topic(user_id=user_id, name=payload.name, color=payload.color)
    session.add(topic)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Тема с таким именем уже существует") from exc
    await session.refresh(topic)
    return topic


@router.patch("/{topic_id}", response_model=TopicRead, summary="Обновить тему")
async def update_topic(
    topic_id: int, payload: TopicUpdate, session: SessionDep, user_id: UserIdDep
) -> Topic:
    topic = await _get(session, topic_id, user_id)
    data = payload.model_dump(exclude_unset=True)
    for k, v in data.items():
        setattr(topic, k, v)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Конфликт уникальности") from exc
    await session.refresh(topic)
    return topic


@router.delete(
    "/{topic_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить тему",
)
async def delete_topic(topic_id: int, session: SessionDep, user_id: UserIdDep) -> None:
    topic = await _get(session, topic_id, user_id)
    try:
        await session.delete(topic)
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Тема используется в задачах/паттернах — сначала перенесите их.",
        ) from exc


async def _get(session: SessionDep, topic_id: int, user_id: int) -> Topic:
    res = await session.execute(
        select(Topic).where(Topic.id == topic_id, Topic.user_id == user_id)
    )
    topic = res.scalar_one_or_none()
    if topic is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Тема не найдена")
    return topic
