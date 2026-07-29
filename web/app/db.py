"""Acceso pequeño y explícito a MySQL sin ORM."""

from collections.abc import Sequence
from typing import Any

import mysql.connector
from flask import current_app
from mysql.connector import Error as MySQLError
from mysql.connector.connection import MySQLConnection


class DatabaseError(RuntimeError):
    """Error de acceso a datos apto para ser manejado por las rutas."""


ALLOWED_PROCEDURES = frozenset(
    {
        "sp_crear_cliente_vehiculo",
        "sp_crear_orden_trabajo",
        "sp_agregar_detalle_orden",
        "sp_actualizar_diagnostico_orden",
        "sp_cambiar_estado_orden",
        "sp_finalizar_orden",
        "sp_generar_factura",
        "sp_registrar_pago",
        "sp_anular_factura",
        "sp_anular_pago",
    }
)


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


def call_procedure(
    procedure_name: str,
    params: Sequence[Any],
) -> tuple[Any, ...]:
    """Ejecuta un procedimiento permitido y devuelve sus parametros de salida."""
    if procedure_name not in ALLOWED_PROCEDURES:
        raise ValueError("Procedimiento no permitido por la aplicacion.")

    connection: MySQLConnection | None = None
    cursor = None
    try:
        connection = get_connection()
        cursor = connection.cursor()
        result = cursor.callproc(procedure_name, tuple(params))
        for stored_result in cursor.stored_results():
            stored_result.fetchall()
        connection.commit()
        return tuple(result)
    except MySQLError as exc:
        if connection is not None:
            connection.rollback()
        raise DatabaseError("No fue posible completar la operacion.") from exc
    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None and connection.is_connected():
            connection.close()


def mysql_error_message(exc: BaseException) -> str:
    """Expone mensajes SIGNAL 45000 sin filtrar errores internos."""
    cause = exc.__cause__
    if isinstance(cause, MySQLError) and (
        cause.sqlstate == "45000" or cause.errno == 1644
    ):
        return cause.msg
    return "No fue posible completar la operacion. Intentalo nuevamente."
