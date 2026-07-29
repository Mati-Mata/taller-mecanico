"""Pruebas de humo que no requieren una instancia real de MySQL."""

import pytest

from app import create_app


@pytest.fixture()
def app():
    return create_app(
        {
            "TESTING": True,
            "SECRET_KEY": "testing-only-secret",
        }
    )


@pytest.fixture()
def client(app):
    return app.test_client()


def test_create_app_importable(app):
    assert app.name == "app"
    assert app.config["TESTING"] is True


def test_login_responds(client):
    response = client.get("/login")
    assert response.status_code == 200
    assert b"Taller Mec" in response.data


def test_dashboard_requires_login(client):
    response = client.get("/dashboard", follow_redirects=False)
    assert response.status_code == 302
    assert "/login" in response.headers["Location"]


@pytest.mark.parametrize(
    "path",
    (
        "/clientes",
        "/clientes/nuevo",
        "/clientes/1",
        "/vehiculos/1",
        "/ordenes",
        "/ordenes/nueva",
        "/ordenes/1",
        "/facturas",
        "/facturas/1",
    ),
)
def test_operational_routes_require_login(client, path):
    response = client.get(path, follow_redirects=False)
    assert response.status_code == 302
    assert "/login" in response.headers["Location"]


def test_order_transition_matrix():
    from app.ordenes.routes import estados_siguientes

    assert estados_siguientes("ingresada") == ("diagnostico", "cancelada")
    assert "en_reparacion" in estados_siguientes("diagnostico")
    assert estados_siguientes("finalizada") == ()
    assert estados_siguientes("estado_desconocido") == ()


def test_unknown_route_returns_404(client):
    response = client.get("/ruta-que-no-existe")
    assert response.status_code == 404
