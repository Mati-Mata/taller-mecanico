"""Fábrica de la aplicación Flask del taller mecánico."""

from typing import Any

from flask import Flask, jsonify, redirect, render_template, url_for
from flask_login import LoginManager

from .config import Config
from .db import DatabaseError, fetch_one


login_manager = LoginManager()


def create_app(test_config: dict[str, Any] | None = None) -> Flask:
    """Crea y configura una instancia aislada de la aplicación."""
    app = Flask(__name__)
    app.config.from_object(Config)
    if test_config:
        app.config.update(test_config)

    login_manager.init_app(app)
    login_manager.login_view = "auth.login"
    login_manager.login_message = "Inicie sesión para continuar."
    login_manager.login_message_category = "warning"
    login_manager.session_protection = "strong"

    @login_manager.user_loader
    def load_user(user_id: str):
        from .user import get_user_by_id

        try:
            return get_user_by_id(int(user_id))
        except (DatabaseError, TypeError, ValueError):
            return None

    from .auth import bp as auth_bp
    from .dashboard import bp as dashboard_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(dashboard_bp)

    @app.get("/")
    def index():
        from flask_login import current_user

        if current_user.is_authenticated:
            return redirect(url_for("dashboard.index"))
        return redirect(url_for("auth.login"))

    @app.get("/health")
    def health():
        try:
            row = fetch_one(
                """
                    SELECT
                        DATABASE() AS database_name,
                        VERSION() AS mysql_version
                """
            )
        except DatabaseError:
            return (
                jsonify(
                    status="error",
                    database=app.config["MYSQL_DATABASE"],
                    mysql_connected=False,
                    message="No fue posible conectar con MySQL.",
                ),
                503,
            )

        return jsonify(
            status="ok",
            database=(row or {}).get(
                "database_name",
                app.config["MYSQL_DATABASE"],
            ),
            mysql_connected=True,
            mysql_version=(row or {}).get("mysql_version"),
        )

    @app.errorhandler(403)
    def forbidden(_error):
        return render_template("errors/403.html"), 403

    @app.errorhandler(404)
    def not_found(_error):
        return render_template("errors/404.html"), 404

    @app.errorhandler(500)
    def internal_error(_error):
        return render_template("errors/500.html"), 500

    return app
