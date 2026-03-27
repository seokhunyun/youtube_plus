import pymysql
import sys

DB_CONFIG = {
    "host": "b-611.iptime.org",
    "port": 33069,
    "user": "pi",
    "password": "pi1234",
    "database": "youtube_database",
    "charset": "utf8mb4",
    "connect_timeout": 10,
}

def main():
    conn = pymysql.connect(**DB_CONFIG)
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            cursor.execute("SELECT VERSION()")
            version = cursor.fetchone()
            print(f"MySQL Version: {version['VERSION()']}")
            
            print("\nCreating idx_published_at...")
            try:
                cursor.execute("CREATE INDEX idx_published_at ON t_video(publishedAt)")
                conn.commit()
                print("Created idx_published_at.")
            except Exception as e:
                print(f"Skipped idx_published_at: {e}")

            print("\nCreating idx_channel_date...")
            try:
                cursor.execute("CREATE INDEX idx_channel_date ON t_video(channel_id, publishedAt)")
                conn.commit()
                print("Created idx_channel_date.")
            except Exception as e:
                print(f"Skipped idx_channel_date: {e}")

            print("\nCreating FULLTEXT index on title with ngram...")
            try:
                cursor.execute("CREATE FULLTEXT INDEX idx_ft_title ON t_video(title) WITH PARSER ngram")
                conn.commit()
                print("Created idx_ft_title.")
            except Exception as e:
                print(f"Failed to create FULLTEXT index idx_ft_title: {e}")
                print("Trying to create regular FULLTEXT index without ngram...")
                try:
                    cursor.execute("CREATE FULLTEXT INDEX idx_ft_title ON t_video(title)")
                    conn.commit()
                    print("Created regular idx_ft_title.")
                except Exception as e2:
                    print(f"Skipped idx_ft_title: {e2}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()
