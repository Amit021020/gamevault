from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.orm import Session
from .security import hash_password
from .database import Base, engine, get_db
from .models import User
from .schemas import UserCreate, UserResponse
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(title="GameVault API")


@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)


Instrumentator().instrument(app).expose(
    app,
    endpoint="/metrics",
    include_in_schema=False
)


@app.get("/")
def root():
    return {
        "message": "Welcome to GameVault v2"
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "gamevault-api"
    }


@app.post("/users", response_model=UserResponse)
def create_user(
    user: UserCreate,
    db: Session = Depends(get_db)
):
    existing_user = (
        db.query(User)
        .filter(
            (User.username == user.username) |
            (User.email == user.email)
        )
        .first()
    )

    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="Username or email already exists"
        )

    new_user = User(
        username=user.username,
        email=user.email,
        password_hash=hash_password(user.password)
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return new_user


@app.get("/users/{user_id}", response_model=UserResponse)
def get_user(
    user_id: int,
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.id == user_id).first()

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    return user