from fastapi import FastAPI, HTTPException, Path
from fastapi.responses import Response, JSONResponse
from contextlib import asynccontextmanager
from datetime import date
from app.models import User
from app.schemas import UserCreate
from app.database import SessionLocal, engine, Base
from sqlalchemy import func

# ✅ Lifespan: Ensures DB schema is created at startup
@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(lifespan=lifespan)


@app.put("/hello/{username}", status_code=204)
def put_hello(
    username: str = Path(..., pattern="^[a-zA-Z]+$"),
    data: UserCreate = None
):
    if data is None:
        raise HTTPException(status_code=400, detail="Missing request body")

    if data.dateOfBirth >= date.today():
        raise HTTPException(status_code=400, detail="Date of birth must be before today")

    db = SessionLocal()
    user = db.query(User).filter(func.lower(User.name) == username.lower()).first()
    if user:
        user.date_of_birth = data.dateOfBirth
    else:
        user = User(name=username, date_of_birth=data.dateOfBirth)
        db.add(user)

    db.commit()
    db.close()
    return Response(status_code=204)


@app.get("/hello/{username}")
def get_hello(username: str = Path(..., pattern="^[a-zA-Z]+$")):
    db = SessionLocal()
    user = db.query(User).filter(func.lower(User.name) == username.lower()).first()
    if not user:
        db.close()
        raise HTTPException(status_code=404, detail="User not found")

    today = date.today()
    try:
        birthday_this_year = user.date_of_birth.replace(year=today.year)
    except ValueError:
        # Handle Feb 29 on non-leap year
        birthday_this_year = date(today.year, 3, 1)

    if birthday_this_year < today:
        try:
            birthday_next = user.date_of_birth.replace(year=today.year + 1)
        except ValueError:
            birthday_next = date(today.year + 1, 3, 1)
    else:
        birthday_next = birthday_this_year

    days_left = (birthday_next - today).days

    db.close()

    if days_left == 0:
        message = f"Hello, {username}! Happy birthday!"
    else:
        message = f"Hello, {username}! Your birthday is in {days_left} day(s)"

    return JSONResponse(content={"message": message})
