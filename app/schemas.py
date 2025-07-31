from pydantic import BaseModel
from datetime import date

class UserCreate(BaseModel):
    dateOfBirth: date
