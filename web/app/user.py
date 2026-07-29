"""Modelo de sesión y autorización por rol."""

from dataclasses import dataclass
from functools import wraps
from typing import Any, Callable, TypeVar, cast

from flask import abort
from flask_login import UserMixin, current_user, login_required
from werkzeug.security import check_password_hash

from .db import fetch_one


F = TypeVar("F", bound=Callable[..., Any])


@dataclass
class User(UserMixin):
    """Usuario de aplicación compatible con Flask-Login."""

    id_usuario: int
    nombre_usuario: str
    nombres: str
    apellidos: str
    rol: str

    def get_id(self) -> str:
        return str(self.id_usuario)

    @property
    def nombre_completo(self) -> str:
        return f"{self.nombres} {self.apellidos}".strip()

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "User":
        return cls(
            id_usuario=row["id_usuario"],
            nombre_usuario=row["nombre_usuario"],
            nombres=row["nombres"],
            apellidos=row["apellidos"],
            rol=row["rol"],
        )


USER_QUERY = """
    SELECT
        u.id_usuario,
        u.nombre_usuario,
        u.password_hash,
        u.nombres,
        u.apellidos,
        u.activo AS usuario_activo,
        r.nombre AS rol,
        r.activo AS rol_activo
    FROM usuario AS u
    INNER JOIN rol AS r ON r.id_rol = u.id_rol
"""


def get_user_by_id(user_id: int) -> User | None:
    """Recupera un usuario activo para restaurar la sesión."""
    row = fetch_one(
        USER_QUERY
        + """
          WHERE u.id_usuario = %s
            AND u.activo = 1
            AND r.activo = 1
        """,
        (user_id,),
    )
    return User.from_row(row) if row else None


def authenticate_user(username: str, password: str) -> User | None:
    """Valida credenciales sin revelar qué condición falló."""
    row = fetch_one(
        USER_QUERY + " WHERE u.nombre_usuario = %s",
        (username,),
    )
    if not row:
        return None
    if row["usuario_activo"] != 1 or row["rol_activo"] != 1:
        return None
    if not check_password_hash(row["password_hash"], password):
        return None
    return User.from_row(row)


def roles_required(*allowed_roles: str) -> Callable[[F], F]:
    """Exige autenticación y uno de los roles indicados."""

    def decorator(view: F) -> F:
        @wraps(view)
        @login_required
        def wrapped(*args: Any, **kwargs: Any) -> Any:
            if current_user.rol not in allowed_roles:
                abort(403)
            return view(*args, **kwargs)

        return cast(F, wrapped)

    return decorator
