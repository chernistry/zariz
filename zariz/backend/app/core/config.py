from pydantic import BaseModel
import os


class Settings(BaseModel):
    db_url: str = (
        f"postgresql://{os.getenv('POSTGRES_USER','zariz')}:{os.getenv('POSTGRES_PASSWORD','zariz')}@"
        f"{os.getenv('POSTGRES_HOST','localhost')}:{os.getenv('POSTGRES_PORT','5432')}/"
        f"{os.getenv('POSTGRES_DB','zariz')}"
    )
    jwt_secret: str = os.getenv("API_JWT_SECRET", "dev_secret_change_me")
    jwt_algo: str = "HS256"


settings = Settings()

