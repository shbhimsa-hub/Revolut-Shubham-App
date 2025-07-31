import time
import os
import psycopg2
from psycopg2 import OperationalError
from dotenv import load_dotenv

load_dotenv()

print("⏳ Waiting for PostgreSQL to become available...")

while True:
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST"),
            port=os.getenv("DB_PORT"),
            user="postgres",  # root superuser
            password="postgres",
            dbname="postgres"
        )
        conn.autocommit = True
        break
    except OperationalError:
        print("⏳ Still waiting for PostgreSQL...")
        time.sleep(1)

print("✅ PostgreSQL is ready.")

# 🔁 Bootstrap DB
print("⚙️ Running DB setup SQL...")

cur = conn.cursor()
cur.execute("SELECT 1 FROM pg_roles WHERE rolname='revolutuser'")
if not cur.fetchone():
    cur.execute("CREATE ROLE revolutuser WITH LOGIN PASSWORD 'revolutpass'")
    print("✅ Created role revolutuser")
else:
    print("ℹ️ Role revolutuser already exists")

cur.execute("SELECT 1 FROM pg_database WHERE datname='shubhamdb'")
if not cur.fetchone():
    cur.execute("CREATE DATABASE shubhamdb OWNER revolutuser")
    print("✅ Created database shubhamdb")
else:
    print("ℹ️ Database shubhamdb already exists")

cur.execute("GRANT ALL PRIVILEGES ON DATABASE shubhamdb TO revolutuser")
print("✅ Granted privileges to revolutuser")
