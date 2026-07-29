"""Blueprint de clientes y vehiculos."""

from flask import Blueprint

bp = Blueprint("clientes", __name__)

from . import routes  # noqa: E402,F401
