from sqlalchemy import inspect, text
from core.database import engine

inspector = inspect(engine)
columns = {column["name"] for column in inspector.get_columns("users")}

with engine.begin() as connection:
    if "employee_id" not in columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN employee_id VARCHAR(36)")
        )
        print("Added employee_id")
    else:
        print("employee_id already exists")

    if "token_invalid_before" not in columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN token_invalid_before DATETIME")
        )
        print("Added token_invalid_before")
    else:
        print("token_invalid_before already exists")

print("Migration finished.")
