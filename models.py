from pydantic import BaseModel, EmailStr


class Product(BaseModel):
    name: str
    price: float
    quantity: int
    category: str


class User(BaseModel):
    username: str
    email: EmailStr
    full_name: str | None = None


class Supplier(BaseModel):
    name: str
    contact_email: EmailStr
    phone: str | None = None