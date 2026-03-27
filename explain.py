import pymysql

DB_CONFIG = {
    "host": "b-611.iptime.org",
    "port": 33069,
    "user": "pi",
    "password": "pi1234",
    "database": "youtube_database",
    "charset": "utf8mb4",
    "connect_timeout": 5,
}

conn = pymysql.connect(**DB_CONFIG)
with conn.cursor() as cur:
    cur.execute("SHOW PROCESSLIST")
    for r in cur.fetchall():
        if r[4] != "Sleep":
            print(r)
    
    print("\nEXPLAIN results:")
    cur.execute("EXPLAIN SELECT v.videoid FROM t_video v FORCE INDEX (idx_published_at) WHERE v.title LIKE '%테스트%' ORDER BY v.publishedAt DESC LIMIT 50")
    print(cur.fetchall())
