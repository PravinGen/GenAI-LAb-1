from fastapi import APIRouter
from models import Product

router = APIRouter(prefix="/products", tags=["products"])


@router.get("/")
async def read_products() -> list[Product]:
    return []


@router.post("/")
async def create_product(product: Product) -> Product:
    return product