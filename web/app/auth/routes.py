"""Rutas de inicio y cierre de sesión."""

from flask import flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required, login_user, logout_user

from app.db import DatabaseError
from app.user import authenticate_user

from . import bp


@bp.route("/login", methods=["GET", "POST"])
def login():
    """Autentica usuarios activos con roles activos."""
    if current_user.is_authenticated:
        return redirect(url_for("dashboard.index"))

    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")

        try:
            user = authenticate_user(username, password)
        except DatabaseError:
            flash(
                "No fue posible validar el acceso. Compruebe la conexión con MySQL.",
                "danger",
            )
            return render_template("auth/login.html"), 503

        if user is None:
            flash("Usuario o contraseña incorrectos.", "danger")
        else:
            login_user(user, remember=False)
            flash(f"Bienvenido, {user.nombre_completo}.", "success")
            return redirect(url_for("dashboard.index"))

    return render_template("auth/login.html")


@bp.post("/logout")
@login_required
def logout():
    """Cierra la sesión actual sin exponer información sensible."""
    logout_user()
    flash("La sesión se cerró correctamente.", "info")
    return redirect(url_for("auth.login"))
