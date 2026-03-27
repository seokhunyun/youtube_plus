from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import pymysql
import sqlite3
import os
from datetime import datetime
from typing import Optional
import uvicorn

app = FastAPI(title="YouTube Plus API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_CONFIG = {
    "host": "b-611.iptime.org",
    "port": 33069,
    "user": "pi",
    "password": "pi1234",
    "database": "youtube_database",
    "charset": "utf8mb4",
    "connect_timeout": 10,
}

LOCAL_DB_PATH = os.path.join(os.path.dirname(__file__), "local_data.db")


def get_db():
    return pymysql.connect(**DB_CONFIG)


def init_local_db():
    conn = sqlite3.connect(LOCAL_DB_PATH)
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            videoid TEXT NOT NULL,
            channel_id TEXT,
            title TEXT,
            thumbnail TEXT,
            watched_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS favorite_channels (
            channel_id TEXT PRIMARY KEY,
            channel_name TEXT,
            thumbnail TEXT,
            added_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS user_playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS user_playlist_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            playlist_id INTEGER NOT NULL,
            videoid TEXT NOT NULL,
            title TEXT,
            thumbnail TEXT,
            channel_id TEXT,
            channel_name TEXT,
            added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (playlist_id) REFERENCES user_playlists(id)
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS watch_progress (
            videoid TEXT PRIMARY KEY,
            position_seconds REAL NOT NULL DEFAULT 0,
            duration_seconds REAL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()


init_local_db()


# ─── Channels ────────────────────────────────────────────────────────────────

@app.get("/channels")
def get_channels(limit: int = 50, offset: int = 0, category: Optional[int] = None):
    conn = get_db()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            if category is not None:
                sql = """
                    SELECT y.channel_id, y.channel_name, y.category, y.ranking,
                           (SELECT COUNT(videoid) FROM t_video WHERE channel_id = y.channel_id) AS video_cnt,
                           p.thumbnail
                    FROM t_youtuber_list y
                    LEFT JOIN t_playlist p ON p.channel_id = y.channel_id
                    WHERE y.category = %s
                    GROUP BY y.channel_id
                    ORDER BY y.ranking ASC
                    LIMIT %s OFFSET %s
                """
                cursor.execute(sql, (category, limit, offset))
            else:
                sql = """
                    SELECT y.channel_id, y.channel_name, y.category, y.ranking,
                           (SELECT COUNT(videoid) FROM t_video WHERE channel_id = y.channel_id) AS video_cnt,
                           p.thumbnail
                    FROM t_youtuber_list y
                    LEFT JOIN t_playlist p ON p.channel_id = y.channel_id
                    GROUP BY y.channel_id
                    ORDER BY y.ranking ASC
                    LIMIT %s OFFSET %s
                """
                cursor.execute(sql, (limit, offset))
            return cursor.fetchall()
    finally:
        conn.close()


@app.get("/channels/search")
def search_channels(q: str = Query(...), limit: int = 30):
    conn = get_db()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            sql = """
                SELECT y.channel_id, y.channel_name, y.category, y.ranking,
                       (SELECT COUNT(videoid) FROM t_video WHERE channel_id = y.channel_id) AS video_cnt,
                       p.thumbnail
                FROM t_youtuber_list y
                LEFT JOIN t_playlist p ON p.channel_id = y.channel_id
                WHERE y.channel_name LIKE %s
                GROUP BY y.channel_id
                ORDER BY y.ranking ASC
                LIMIT %s
            """
            cursor.execute(sql, (f"%{q}%", limit))
            return cursor.fetchall()
    finally:
        conn.close()


@app.get("/channels/{channel_id}")
def get_channel(channel_id: str):
    conn = get_db()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            cursor.execute("""
                SELECT y.channel_id, y.channel_name, y.category, y.ranking,
                       (SELECT COUNT(videoid) FROM t_video WHERE channel_id = y.channel_id) AS video_cnt,
                       p.thumbnail
                FROM t_youtuber_list y
                LEFT JOIN t_playlist p ON p.channel_id = y.channel_id
                WHERE y.channel_id = %s
                GROUP BY y.channel_id
            """, (channel_id,))
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Channel not found")
            return row
    finally:
        conn.close()


@app.get("/channels/{channel_id}/videos")
def get_channel_videos(
    channel_id: str,
    limit: int = 30,
    offset: int = 0,
    sort: str = "date_desc"
):
    conn = get_db()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            order = "v.publishedAt DESC" if sort == "date_desc" else "v.publishedAt ASC"
            sql = f"""
                SELECT v.videoid, v.channel_id, v.title, v.thumbnail, v.publishedAt,
                       y.channel_name
                FROM t_video v
                LEFT JOIN t_youtuber_list y ON y.channel_id = v.channel_id
                WHERE v.channel_id = %s
                ORDER BY {order}
                LIMIT %s OFFSET %s
            """
            cursor.execute(sql, (channel_id, limit, offset))
            rows = cursor.fetchall()
            for r in rows:
                if isinstance(r.get("publishedAt"), datetime):
                    r["publishedAt"] = r["publishedAt"].isoformat()
            return rows
    finally:
        conn.close()


# ─── Videos ──────────────────────────────────────────────────────────────────

@app.get("/videos/latest")
def get_latest_videos(limit: int = 20, channel_ids: Optional[str] = None):
    conn = get_db()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            if channel_ids:
                ids = channel_ids.split(",")
                placeholders = ",".join(["%s"] * len(ids))
                sql = f"""
                    SELECT v.videoid, v.channel_id, v.title, v.thumbnail, v.publishedAt,
                           y.channel_name
                    FROM t_video v FORCE INDEX (idx_channel_date)
                    LEFT JOIN t_youtuber_list y ON y.channel_id = v.channel_id
                    WHERE v.channel_id IN ({placeholders})
                    ORDER BY v.publishedAt DESC
                    LIMIT %s
                """
                cursor.execute(sql, (*ids, limit))
            else:
                sql = """
                    SELECT v.videoid, v.channel_id, v.title, v.thumbnail, v.publishedAt,
                           y.channel_name
                    FROM t_video v FORCE INDEX (idx_published_at)
                    LEFT JOIN t_youtuber_list y ON y.channel_id = v.channel_id
                    ORDER BY v.publishedAt DESC
                    LIMIT %s
                """
                cursor.execute(sql, (limit,))
            rows = cursor.fetchall()
            for r in rows:
                if isinstance(r.get("publishedAt"), datetime):
                    r["publishedAt"] = r["publishedAt"].isoformat()
            return rows
    finally:
        conn.close()


@app.get("/videos/search")
def search_videos(
    q: str = Query(...),
    channel_id: Optional[str] = None,
    sort: str = "date_desc",
    limit: int = 50,
    offset: int = 0
):
    conn = get_db()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            order_map = {
                "date_desc": "v.publishedAt DESC",
                "date_asc": "v.publishedAt ASC",
            }
            order = order_map.get(sort, "v.publishedAt DESC")

            if channel_id:
                sql = f"""
                    SELECT v.videoid, v.channel_id, v.title, v.thumbnail, v.publishedAt,
                           y.channel_name
                    FROM t_video v FORCE INDEX (idx_channel_date)
                    LEFT JOIN t_youtuber_list y ON y.channel_id = v.channel_id
                    WHERE v.title LIKE %s AND v.channel_id = %s
                    ORDER BY {order}
                    LIMIT %s OFFSET %s
                """
                cursor.execute(sql, (f"%{q}%", channel_id, limit, offset))
            else:
                sql = f"""
                    SELECT v.videoid, v.channel_id, v.title, v.thumbnail, v.publishedAt,
                           y.channel_name
                    FROM t_video v FORCE INDEX (idx_published_at)
                    LEFT JOIN t_youtuber_list y ON y.channel_id = v.channel_id
                    WHERE v.title LIKE %s
                    ORDER BY {order}
                    LIMIT %s OFFSET %s
                """
                cursor.execute(sql, (f"%{q}%", limit, offset))
            rows = cursor.fetchall()
            for r in rows:
                if isinstance(r.get("publishedAt"), datetime):
                    r["publishedAt"] = r["publishedAt"].isoformat()
            return rows
    finally:
        conn.close()


# ─── Playlists (DB) ───────────────────────────────────────────────────────────

@app.get("/playlists")
def get_playlists(channel_id: Optional[str] = None, limit: int = 20):
    conn = get_db()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            if channel_id:
                cursor.execute(
                    "SELECT * FROM t_playlist WHERE channel_id = %s LIMIT %s",
                    (channel_id, limit)
                )
            else:
                cursor.execute("SELECT * FROM t_playlist LIMIT %s", (limit,))
            rows = cursor.fetchall()
            for r in rows:
                if isinstance(r.get("publishedAt"), datetime):
                    r["publishedAt"] = r["publishedAt"].isoformat()
            return rows
    finally:
        conn.close()


@app.get("/playlists/{playlist_id}/videos")
def get_playlist_videos(playlist_id: str, limit: int = 30, offset: int = 0):
    conn = get_db()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            sql = """
                SELECT v.videoid, v.channel_id, v.title, v.thumbnail, v.publishedAt,
                       y.channel_name
                FROM t_mapping m
                JOIN t_video v ON v.videoid = m.videoid
                LEFT JOIN t_youtuber_list y ON y.channel_id = v.channel_id
                WHERE m.playlistId = %s
                ORDER BY v.publishedAt DESC
                LIMIT %s OFFSET %s
            """
            cursor.execute(sql, (playlist_id, limit, offset))
            rows = cursor.fetchall()
            for r in rows:
                if isinstance(r.get("publishedAt"), datetime):
                    r["publishedAt"] = r["publishedAt"].isoformat()
            return rows
    finally:
        conn.close()


# ─── History (SQLite local) ───────────────────────────────────────────────────

@app.get("/history")
def get_history(limit: int = 20):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(
            "SELECT * FROM history ORDER BY watched_at DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


@app.post("/history")
def add_history(data: dict):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    try:
        conn.execute(
            "INSERT INTO history (videoid, channel_id, title, thumbnail) VALUES (?, ?, ?, ?)",
            (data.get("videoid"), data.get("channel_id"), data.get("title"), data.get("thumbnail"))
        )
        conn.commit()
    finally:
        conn.close()
    return {"status": "ok"}


# ─── Favorite Channels (SQLite local) ────────────────────────────────────────

@app.get("/favorites/channels")
def get_favorite_channels():
    conn = sqlite3.connect(LOCAL_DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(
            "SELECT * FROM favorite_channels ORDER BY added_at DESC"
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


@app.post("/favorites/channels")
def add_favorite_channel(data: dict):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    try:
        conn.execute(
            "INSERT OR IGNORE INTO favorite_channels (channel_id, channel_name, thumbnail) VALUES (?, ?, ?)",
            (data.get("channel_id"), data.get("channel_name"), data.get("thumbnail"))
        )
        conn.commit()
    finally:
        conn.close()
    return {"status": "ok"}


@app.delete("/favorites/channels/{channel_id}")
def remove_favorite_channel(channel_id: str):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    try:
        conn.execute("DELETE FROM favorite_channels WHERE channel_id = ?", (channel_id,))
        conn.commit()
    finally:
        conn.close()
    return {"status": "ok"}


# ─── User Playlists (SQLite local) ───────────────────────────────────────────

@app.get("/user-playlists")
def get_user_playlists():
    conn = sqlite3.connect(LOCAL_DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        playlists = conn.execute(
            "SELECT * FROM user_playlists ORDER BY created_at DESC"
        ).fetchall()
        result = []
        for p in playlists:
            pd = dict(p)
            items = conn.execute(
                "SELECT * FROM user_playlist_items WHERE playlist_id = ? ORDER BY added_at ASC",
                (p["id"],)
            ).fetchall()
            pd["items"] = [dict(i) for i in items]
            pd["item_count"] = len(pd["items"])
            result.append(pd)
        return result
    finally:
        conn.close()


@app.post("/user-playlists")
def create_user_playlist(data: dict):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    try:
        cursor = conn.execute(
            "INSERT INTO user_playlists (name, description) VALUES (?, ?)",
            (data.get("name"), data.get("description", ""))
        )
        conn.commit()
        return {"id": cursor.lastrowid, "status": "ok"}
    finally:
        conn.close()


@app.delete("/user-playlists/{playlist_id}")
def delete_user_playlist(playlist_id: int):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    try:
        conn.execute("DELETE FROM user_playlist_items WHERE playlist_id = ?", (playlist_id,))
        conn.execute("DELETE FROM user_playlists WHERE id = ?", (playlist_id,))
        conn.commit()
    finally:
        conn.close()
    return {"status": "ok"}


@app.post("/user-playlists/{playlist_id}/videos")
def add_video_to_user_playlist(playlist_id: int, data: dict):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    try:
        conn.execute(
            """INSERT INTO user_playlist_items
               (playlist_id, videoid, title, thumbnail, channel_id, channel_name)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (playlist_id, data.get("videoid"), data.get("title"),
             data.get("thumbnail"), data.get("channel_id"), data.get("channel_name"))
        )
        conn.commit()
    finally:
        conn.close()
    return {"status": "ok"}


@app.delete("/user-playlists/{playlist_id}/videos/{video_id}")
def remove_video_from_user_playlist(playlist_id: int, video_id: str):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    try:
        conn.execute(
            "DELETE FROM user_playlist_items WHERE playlist_id = ? AND videoid = ?",
            (playlist_id, video_id)
        )
        conn.commit()
    finally:
        conn.close()
    return {"status": "ok"}


# ─── Watch Progress (SQLite local) ──────────────────────────────────────────

@app.get("/watch-progress/{videoid}")
def get_watch_progress(videoid: str):
    conn = sqlite3.connect(LOCAL_DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        row = conn.execute(
            "SELECT * FROM watch_progress WHERE videoid = ?", (videoid,)
        ).fetchone()
        if row:
            return dict(row)
        return {"videoid": videoid, "position_seconds": 0, "duration_seconds": None}
    finally:
        conn.close()


@app.post("/watch-progress")
def save_watch_progress(data: dict):
    videoid = data.get("videoid")
    position = data.get("position_seconds", 0)
    duration = data.get("duration_seconds")
    if not videoid:
        return {"status": "error", "message": "videoid required"}
    conn = sqlite3.connect(LOCAL_DB_PATH)
    try:
        conn.execute(
            """
            INSERT INTO watch_progress (videoid, position_seconds, duration_seconds, updated_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(videoid) DO UPDATE SET
                position_seconds = excluded.position_seconds,
                duration_seconds = excluded.duration_seconds,
                updated_at = CURRENT_TIMESTAMP
            """,
            (videoid, position, duration)
        )
        conn.commit()
    finally:
        conn.close()
    return {"status": "ok"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8765)
