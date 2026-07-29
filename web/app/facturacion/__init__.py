"""Blueprint de facturacion y pagos."""

from flask import Blueprint

bp = Blueprint("facturacion", __name__)

from . import routes  # noqa: E402,F401
