"""Configura de forma interactiva la contraseña local de admin_demo."""

import getpass
import os
import sys
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv
from mysql.connector import Error as MySQLError
from werkzeug.security import generate_password_hash


WEB_ROOT = Path(__file__).resolve().parent
load_dotenv(WEB_ROOT / ".env")


def _connection_config() -> dict[str, object]:
    return {
        "host": os.getenv("MYSQL_HOST", "127.0.0.1"),
        "port": int(os.getenv("MYSQL_PORT", "3306")),
        "database": os.getenv("MYSQL_DATABASE", "taller_mecanico"),
        "user": os.getenv("MYSQL_USER", ""),
        "password": os.getenv("MYSQL_PASSWORD", ""),
        "autocommit": False,
    }


def _read_password() -> str:
    password = getpass.getpass("Nueva contraseña para admin_demo: ")
    confirmation = getpass.getpass("Repita la contraseña: ")
    if password != confirmation:
        raise ValueError("Las contraseñas no coinciden.")
    if len(password) < 8:
        raise ValueError("La contraseña debe tener al menos 8 caracteres.")
    return password


def main() -> int:
    connection = None
    cursor = None
    try:
        connection = mysql.connector.connect(**_connection_config())
        cursor = connection.cursor(dictionary=True)
        cursor.execute(
            """
                SELECT u.id_usuario, r.nombre AS rol
                FROM usuario AS u
                INNER JOIN rol AS r ON r.id_rol = u.id_rol
                WHERE u.nombre_usuario = %s
            """,
            ("admin_demo",),
        )
        admin = cursor.fetchone()

        if admin is None:
            print(
                "admin_demo no existe. Ejecute primero database/08_seed_data.sql.",
                file=sys.stderr,
            )
            return 1
        if admin["rol"] != "administrador":
            print(
                "admin_demo no tiene el rol administrador esperado.",
                file=sys.stderr,
            )
            return 1

        password_hash = generate_password_hash(_read_password())

        cursor.execute("SET @app_id_usuario = %s", (admin["id_usuario"],))
        cursor.execute("SET @app_origen = %s", ("set_demo_password",))
        cursor.execute(
            "SET @app_motivo = %s",
            ("Configuracion local de acceso administrativo",),
        )
        cursor.execute(
            """
                UPDATE usuario
                SET password_hash = %s
                WHERE id_usuario = %s
            """,
            (password_hash, admin["id_usuario"]),
        )
        if cursor.rowcount != 1:
            raise RuntimeError("No fue posible actualizar admin_demo.")

        connection.commit()
        cursor.execute("SET @app_id_usuario = NULL")
        cursor.execute("SET @app_origen = NULL")
        cursor.execute("SET @app_motivo = NULL")
        print("Contraseña local de admin_demo configurada correctamente.")
        return 0
    except (MySQLError, RuntimeError, ValueError) as exc:
        if connection is not None:
            connection.rollback()
        print(f"No fue posible configurar el acceso: {exc}", file=sys.stderr)
        return 1
    finally:
        if cursor is not None:
            try:
                cursor.execute("SET @app_id_usuario = NULL")
                cursor.execute("SET @app_origen = NULL")
                cursor.execute("SET @app_motivo = NULL")
            except MySQLError:
                pass
            cursor.close()
        if connection is not None and connection.is_connected():
            connection.close()


if __name__ == "__main__":
    raise SystemExit(main())
