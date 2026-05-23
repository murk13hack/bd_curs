"""CRUD тегов."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import Tag
from app.schemas.tag import TagCreate, TagRead, TagUpdate

router = APIRouter(prefix="/tags", tags=["tags"])


@router.get("", response_model=list[TagRead], summary="Список тегов")
async def list_tags(session: SessionDep, user_id: UserIdDep) -> list[Tag]:
    res = await session.execute(select(Tag).where(Tag.user_id == user_id).order_by(Tag.name))
    return list(res.scalars())


@router.post("", response_model=TagRead, status_code=status.HTTP_201_CREATED, summary="Создать тег")
async def create_tag(payload: TagCreate, session: SessionDep, user_id: UserIdDep) -> Tag:
    tag = Tag(user_id=user_id, name=payload.name)
    session.add(tag)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Тег с таким именем уже есть") from exc
    await session.refresh(tag)
    return tag


@router.patch("/{tag_id}", response_model=TagRead, summary="Переименовать тег")
async def update_tag(
    tag_id: int, payload: TagUpdate, session: SessionDep, user_id: UserIdDep
) -> Tag:
    tag = await _get(session, tag_id, user_id)
    if payload.name is not None:
        tag.name = payload.name
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Конфликт уникальности") from exc
    await session.refresh(tag)
    return tag


@router.delete(
    "/{tag_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить тег",
)
async def delete_tag(tag_id: int, session: SessionDep, user_id: UserIdDep) -> None:
    tag = await _get(session, tag_id, user_id)
    await session.delete(tag)
    await session.commit()


async def _get(session: SessionDep, tag_id: int, user_id: int) -> Tag:
    res = await session.execute(select(Tag).where(Tag.id == tag_id, Tag.user_id == user_id))
    tag = res.scalar_one_or_none()
    if tag is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Тег не найден")
    return tag
