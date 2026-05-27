from fastapi import FastAPI, Header

from models import Product, User, Supplier
from routers.v1.products import router as product_router

app = FastAPI(title="Inventory API")

APP_V1 = "/api/v1"
app.include_router(product_router, prefix=APP_V1)


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/users")
async def create_user(user: User):
    return user


@app.post("/suppliers")
async def create_supplier(supplier: Supplier):
    return supplier


@app.get("/profile")
async def profile(
    authorization: str = Header(),
    version: str = Header(default="v1")
):
    return {
        "received_token": authorization,
        "version": version
    }