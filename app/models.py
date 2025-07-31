from sqlalchemy import Column, Integer, String, Date
from app.database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    date_of_birth = Column(Date)
