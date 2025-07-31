from datetime import date, timedelta

def test_put_valid_user(client):
    username = "Shubham"
    dob = (date.today() - timedelta(days=10000)).isoformat()

    res = client.put(f"/hello/{username}", json={"dateOfBirth": dob})
    assert res.status_code == 204

def test_get_existing_user(client):
    username = "Shubham"

    res = client.get(f"/hello/{username}")
    assert res.status_code == 200
    assert "message" in res.json()

def test_put_future_dob(client):
    username = "FutureGuy"
    future_dob = (date.today() + timedelta(days=1)).isoformat()

    res = client.put(f"/hello/{username}", json={"dateOfBirth": future_dob})
    assert res.status_code == 400
    assert res.json()["detail"] == "Date of birth must be before today"

def test_put_invalid_username(client):
    username = "123Invalid"

    res = client.put(f"/hello/{username}", json={"dateOfBirth": "1990-01-01"})
    assert res.status_code == 422  # FastAPI path validator fails

def test_get_nonexistent_user(client):
    res = client.get("/hello/NotThere")
    assert res.status_code == 404
    assert res.json()["detail"] == "User not found"
