"""Чтение и обновление пользовательских настроек."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import AppSetting
from app.schemas.settings import AppSettingRead, AppSettingUpsert

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("", response_model=list[AppSettingRead], summary="Все настройки")
async def list_settings(session: SessionDep, user_id: UserIdDep) -> list[AppSetting]:
    res = await session.execute(
        select(AppSetting).where(AppSetting.user_id == user_id).order_by(AppSetting.key)
    )
    return list(res.scalars())


@router.get("/{key}", response_model=AppSettingRead, summary="Настройка по ключу")
async def get_setting(key: str, session: SessionDep, user_id: UserIdDep) -> AppSetting:
    item = await _get(session, user_id, key)
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Не найдено")
    return item


@router.put("/{key}", response_model=AppSettingRead, summary="Создать/обновить настройку")
async def upsert_setting(
    key: str, payload: AppSettingUpsert, session: SessionDep, user_id: UserIdDep
) -> AppSetting:
    if payload.key != key:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "key в URL и body должны совпадать")
    item = await _get(session, user_id, key)
    if item is None:
        item = AppSetting(user_id=user_id, key=key, value=payload.value)
        session.add(item)
    else:
        item.value = payload.value
    await session.commit()
    await session.refresh(item)
    return item


@router.delete(
    "/{key}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить настройку",
)
async def delete_setting(key: str, session: SessionDep, user_id: UserIdDep) -> None:
    item = await _get(session, user_id, key)
    if item is None:
        return
    await session.delete(item)
    await session.commit()


async def _get(session: SessionDep, user_id: int, key: str) -> AppSetting | None:
    res = await session.execute(
        select(AppSetting).where(AppSetting.user_id == user_id, AppSetting.key == key)
    )
    return res.scalar_one_or_none()
