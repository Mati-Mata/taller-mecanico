"""Configuración de la aplicación obtenida desde el entorno local."""

import os
from pathlib import Path

from dotenv import load_dotenv


WEB_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(WEB_ROOT / ".env")


def _as_bool(value: str | None, default: bool = False) -> bool:
    """Convierte valores habituales del entorno a booleanos."""
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


class Config:
    """Valores predeterminados seguros para la ejecución local."""

    SECRET_KEY = os.getenv(
        "FLASK_SECRET_KEY",
        "configure-un-secreto-local-en-el-archivo-env",
    )
    DEBUG = _as_bool(os.getenv("FLASK_DEBUG"), False)
    FLASK_HOST = os.getenv("FLASK_HOST", "127.0.0.1")
    FLASK_PORT = int(os.getenv("FLASK_PORT", "5000"))

    MYSQL_HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
    MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
    MYSQL_DATABASE = os.getenv("MYSQL_DATABASE", "taller_mecanico")
    MYSQL_USER = os.getenv("MYSQL_USER", "")
    MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "")

    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    REMEMBER_COOKIE_HTTPONLY = True
    REMEMBER_COOKIE_SAMESITE = "Lax"
