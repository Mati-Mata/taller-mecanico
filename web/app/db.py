"""Acceso pequeño y explícito a MySQL sin ORM."""

from collections.abc import Sequence
from typing import Any

import mysql.connector
from flask import current_app
from mysql.connector import Error as MySQLError
from mysql.connector.connection import MySQLConnection


class DatabaseError(RuntimeError):
    """Error de acceso a datos apto para ser manejado por las rutas."""


def get_connection() -> MySQLConnection:
    """Abre una conexión usando exclusivamente la configuración de Flask."""
    try:
        return mysql.connector.connect(
            host=current_app.config["MYSQL_HOST"],
            port=current_app.config["MYSQL_PORT"],
            database=current_app.config["MYSQL_DATABASE"],
            user=current_app.config["MYSQL_USER"],
            password=current_app.config["MYSQL_PASSWORD"],
            autocommit=False,
        )
    except MySQLError as exc:
        raise DatabaseError("No fue posible conectar con MySQL.") from exc


def fetch_one(
    query: str,
    params: Sequence[Any] | None = None,
) -> dict[str, Any] | None:
    """Ejecuta una consulta parametrizada y devuelve una fila."""
    connection: MySQLConnection | None = None
    cursor = None
    try:
        connection = get_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, tuple(params or ()))
        row = cursor.fetchone()
        return dict(row) if row is not None else None
    except MySQLError as exc:
        raise DatabaseError("No fue posible consultar MySQL.") from exc
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None and connection.is_connected():
            connection.close()


def fetch_all(
    query: str,
    params: Sequence[Any] | None = None,
) -> list[dict[str, Any]]:
    """Ejecuta una consulta parametrizada y devuelve todas las filas."""
    connection: MySQLConnection | None = None
    cursor = None
    try:
        connection = get_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, tuple(params or ()))
        return [dict(row) for row in cursor.fetchall()]
    except MySQLError as exc:
        raise DatabaseError("No fue posible consultar MySQL.") from exc
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None and connection.is_connected():
            connection.close()
