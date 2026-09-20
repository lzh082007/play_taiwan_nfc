import os
from contextlib import asynccontextmanager
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from neo4j import AsyncGraphDatabase
from neo4j.exceptions import Neo4jError, ServiceUnavailable
from pydantic import BaseModel

load_dotenv()

# ── Neo4j 連線設定 ────────────────────────────────────────────────
# 帳密放在 .env（不會進 git），本機第一次跑之前先照 .env.example 複製一份出來填。
NEO4J_URI = os.environ["NEO4J_URI"]
NEO4J_USER = os.environ["NEO4J_USER"]
NEO4J_PASSWORD = os.environ["NEO4J_PASSWORD"]
# playtaiwandb 對應的實際 Neo4j 資料庫名稱是 mergedb（見 schema 文件）。
NEO4J_DATABASE = os.environ["NEO4J_DATABASE"]
# ──────────────────────────────────────────────────────────────

# 用 uid 查 Place 節點：統一查 (:Place) 標籤即可涵蓋 Attraction/Event/Hotel/
# Restaurant 四種實體。Event 的名稱/介紹欄位跟其他三種不同（EventName/
# Description 而非 name/description），用 coalesce() 兩邊都吃。
# type 則是取除了 Place 以外的第一個 label（Attraction/Event/Hotel/Restaurant）。
PLACE_BY_UID_QUERY = """
MATCH (p:Place {uid: $uid})
OPTIONAL MATCH (p)-[:HAS_IMAGE]->(img:Image)
WITH p, labels(p) AS labels, collect(img.url)[0] AS firstImageUrl
RETURN p.uid AS uid,
       coalesce(p.name, p.EventName) AS name,
       [t IN labels WHERE t <> 'Place'][0] AS type,
       coalesce(p.description, p.Description) AS description,
       firstImageUrl AS imageUrl
LIMIT 1
"""


class PlaceInfo(BaseModel):
    uid: str
    name: str
    type: str
    description: Optional[str] = None
    imageUrl: Optional[str] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.driver = AsyncGraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
    yield
    await app.state.driver.close()


app = FastAPI(title="NFC Demo Place API", lifespan=lifespan)


@app.get("/place/{uid}", response_model=PlaceInfo)
async def get_place(uid: str) -> PlaceInfo:
    driver = app.state.driver

    try:
        async with driver.session(database=NEO4J_DATABASE) as session:
            result = await session.run(PLACE_BY_UID_QUERY, uid=uid)
            record = await result.single()
    except ServiceUnavailable as e:
        raise HTTPException(
            status_code=503,
            detail=f"無法連線到 Neo4j（{NEO4J_URI}）：{e}。請確認 Neo4j 有啟動。",
        ) from e
    except Neo4jError as e:
        raise HTTPException(status_code=502, detail=f"Neo4j 查詢發生錯誤：{e}") from e

    if record is None or record["name"] is None:
        raise HTTPException(status_code=404, detail="Place not found")

    return PlaceInfo(
        uid=record["uid"],
        name=record["name"],
        type=record["type"] or "",
        description=record["description"],
        imageUrl=record["imageUrl"],
    )
