import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.security import verify_password
from app.database import Base, get_db
from app.main import app
from app.models import User


# TEST DATABASE


SQLALCHEMY_DATABASE_URL = "sqlite://"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

TestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


def override_get_db():
    db = TestingSessionLocal()

    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)



# DATABASE CLEANUP


@pytest.fixture(autouse=True)
def clean_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)



# HEALTH TEST


def test_health():
    response = client.get("/health")

    assert response.status_code == 200

    assert response.json() == {
        "status": "healthy",
        "service": "gamevault-api",
    }



# USER CREATION


def test_create_user():
    response = client.post(
        "/users",
        json={
            "username": "testuser",
            "email": "test@example.com",
            "password": "password123",
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["username"] == "testuser"
    assert data["email"] == "test@example.com"
    assert "id" in data

    # Password must never be returned.
    assert "password" not in data
    assert "password_hash" not in data



# USER RETRIEVAL


def test_get_user():
    create_response = client.post(
        "/users",
        json={
            "username": "testuser",
            "email": "test@example.com",
            "password": "password123",
        },
    )

    assert create_response.status_code == 200

    user_id = create_response.json()["id"]

    response = client.get(f"/users/{user_id}")

    assert response.status_code == 200

    data = response.json()

    assert data["id"] == user_id
    assert data["username"] == "testuser"
    assert data["email"] == "test@example.com"



# NONEXISTENT USER


def test_get_nonexistent_user():
    response = client.get("/users/9999")

    assert response.status_code == 404

    assert response.json() == {
        "detail": "User not found"
    }



# DUPLICATE USER


def test_duplicate_user():
    user = {
        "username": "testuser",
        "email": "test@example.com",
        "password": "password123",
    }

    first_response = client.post(
        "/users",
        json=user,
    )

    second_response = client.post(
        "/users",
        json=user,
    )

    assert first_response.status_code == 200
    assert second_response.status_code == 409

    assert second_response.json() == {
        "detail": "Username or email already exists"
    }



# DUPLICATE USERNAME


def test_duplicate_username():
    first_response = client.post(
        "/users",
        json={
            "username": "sameuser",
            "email": "first@example.com",
            "password": "password123",
        },
    )

    second_response = client.post(
        "/users",
        json={
            "username": "sameuser",
            "email": "second@example.com",
            "password": "password123",
        },
    )

    assert first_response.status_code == 200
    assert second_response.status_code == 409

    assert second_response.json() == {
        "detail": "Username or email already exists"
    }



# DUPLICATE EMAIL


def test_duplicate_email():
    first_response = client.post(
        "/users",
        json={
            "username": "firstuser",
            "email": "same@example.com",
            "password": "password123",
        },
    )

    second_response = client.post(
        "/users",
        json={
            "username": "seconduser",
            "email": "same@example.com",
            "password": "password123",
        },
    )

    assert first_response.status_code == 200
    assert second_response.status_code == 409

    assert second_response.json() == {
        "detail": "Username or email already exists"
    }



# INVALID EMAIL


def test_invalid_email():
    response = client.post(
        "/users",
        json={
            "username": "testuser",
            "email": "not-an-email",
            "password": "password123",
        },
    )

    assert response.status_code == 422



# MISSING USERNAME


def test_missing_username():
    response = client.post(
        "/users",
        json={
            "email": "test@example.com",
            "password": "password123",
        },
    )

    assert response.status_code == 422



# MISSING EMAIL


def test_missing_email():
    response = client.post(
        "/users",
        json={
            "username": "testuser",
            "password": "password123",
        },
    )

    assert response.status_code == 422



# MISSING PASSWORD


def test_missing_password():
    response = client.post(
        "/users",
        json={
            "username": "testuser",
            "email": "test@example.com",
        },
    )

    assert response.status_code == 422



# EMPTY REQUEST


def test_empty_user_request():
    response = client.post(
        "/users",
        json={},
    )

    assert response.status_code == 422



# INVALID USER ID


def test_invalid_user_id():
    response = client.get("/users/not-a-number")

    assert response.status_code == 422


# TEST PASSWORD
def test_password_is_hashed():
    response = client.post(
        "/users",
        json={
            "username": "hashuser",
            "email": "hash@example.com",
            "password": "password123",
        },
    )

    assert response.status_code == 200

    with TestingSessionLocal() as db:
        user = db.query(User).filter(User.username == "hashuser").first()

        assert user is not None
        assert user.password_hash != "password123"
        assert verify_password("password123", user.password_hash)
        assert not verify_password("wrong-password", user.password_hash)