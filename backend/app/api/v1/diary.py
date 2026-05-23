"""CRUD дневника + FTS-поиск через fn_search_diary."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import delete, select, text
from sqlalchemy.exc import IntegrityError

from app.api.v1.deps import SessionDep, UserIdDep
from app.models import DiaryEntry, DiaryTag, Tag
from app.schemas.diary import (
    DiaryEntryCreate,
    DiaryEntryRead,
    DiaryEntryUpdate,
    DiarySearchHit,
)

router = APIRouter(prefix="/diary", tags=["diary"])


def _to_read(entry: DiaryEntry) -> DiaryEntryRead:
    return DiaryEntryRead(
        id=entry.id,
        entry_date=entry.entry_date,
        content=entry.content,
        mood=entry.mood,
        energy=entry.energy,
        created_at=entry.created_at,
        updated_at=entry.updated_at,
        tag_ids=[link.tag_id for link in entry.tag_links],
    )


@router.get("", response_model=list[DiaryEntryRead], summary="Список записей дневника")
async def list_entries(
    session: SessionDep,
    user_id: UserIdDep,
    from_: date | None = Query(default=None, alias="from"),
    to: date | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> list[DiaryEntryRead]:
    stmt = select(DiaryEntry).where(DiaryEntry.user_id == user_id)
    if from_ is not None:
        stmt = stmt.where(DiaryEntry.entry_date >= from_)
    if to is not None:
        stmt = stmt.where(DiaryEntry.entry_date <= to)
    stmt = stmt.order_by(DiaryEntry.entry_date.desc()).limit(limit).offset(offset)
    res = await session.execute(stmt)
    return [_to_read(e) for e in res.scalars()]


@router.get("/by-date/{day}", response_model=DiaryEntryRead, summary="Запись по дате")
async def get_by_date(
    day: date, session: SessionDep, user_id: UserIdDep
) -> DiaryEntryRead:
    res = await session.execute(
        select(DiaryEntry).where(
            DiaryEntry.user_id == user_id, DiaryEntry.entry_date == day
        )
    )
    entry = res.scalar_one_or_none()
    if entry is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Записи на эту дату нет")
    return _to_read(entry)


@router.post(
    "",
    response_model=DiaryEntryRead,
    status_code=status.HTTP_201_CREATED,
    summary="Создать запись",
)
async def create_entry(
    payload: DiaryEntryCreate, session: SessionDep, user_id: UserIdDep
) -> DiaryEntryRead:
    entry = DiaryEntry(
        user_id=user_id,
        entry_date=payload.entry_date,
        content=payload.content,
        mood=payload.mood,
        energy=payload.energy,
    )
    session.add(entry)
    try:
        await session.flush()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(
            status.HTTP_409_CONFLICT, "На эту дату запись уже есть"
        ) from exc

    if payload.tag_ids:
        await _replace_tags(session, entry.id, user_id, payload.tag_ids)

    await session.commit()
    await session.refresh(entry, attribute_names=["tag_links"])
    return _to_read(entry)


@router.patch(
    "/{entry_id}", response_model=DiaryEntryRead, summary="Обновить запись"
)
async def update_entry(
    entry_id: int,
    payload: DiaryEntryUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> DiaryEntryRead:
    entry = await _get(session, entry_id, user_id)
    data = payload.model_dump(exclude_unset=True, exclude={"tag_ids"})
    for k, v in data.items():
        setattr(entry, k, v)
    if payload.tag_ids is not None:
        await _replace_tags(session, entry.id, user_id, payload.tag_ids)
    await session.commit()
    await session.refresh(entry, attribute_names=["tag_links"])
    return _to_read(entry)


@router.delete(
    "/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    summary="Удалить запись",
)
async def delete_entry(
    entry_id: int, session: SessionDep, user_id: UserIdDep
) -> None:
    entry = await _get(session, entry_id, user_id)
    await session.delete(entry)
    await session.commit()


@router.get(
    "/search",
    response_model=list[DiarySearchHit],
    summary="Полнотекстовый поиск (fn_search_diary)",
)
async def search(
    session: SessionDep,
    user_id: UserIdDep,
    q: str = Query(min_length=1),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[DiarySearchHit]:
    res = await session.execute(
        text(
            "SELECT entry_id, entry_date, rank, snippet "
            "FROM fn_search_diary(:uid, :q, :lim)"
        ).bindparams(uid=user_id, q=q, lim=limit)
    )
    return [
        DiarySearchHit(entry_id=r[0], entry_date=r[1], rank=float(r[2]), snippet=r[3])
        for r in res
    ]


# ---------- helpers -------------------------------------------------------


async def _get(session: SessionDep, entry_id: int, user_id: int) -> DiaryEntry:
    res = await session.execute(
        select(DiaryEntry).where(
            DiaryEntry.id == entry_id, DiaryEntry.user_id == user_id
        )
    )
    entry = res.scalar_one_or_none()
    if entry is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Запись не найдена")
    return entry


async def _replace_tags(
    session: SessionDep, entry_id: int, user_id: int, tag_ids: list[int]
) -> None:
    if tag_ids:
        ok = await session.execute(
            select(Tag.id).where(Tag.id.in_(tag_ids), Tag.user_id == user_id)
        )
        valid = {row[0] for row in ok.all()}
        if valid != set(tag_ids):
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "Часть тегов не найдена"
            )
    await session.execute(delete(DiaryTag).where(DiaryTag.entry_id == entry_id))
    for tid in tag_ids:
        session.add(DiaryTag(entry_id=entry_id, tag_id=tid))
