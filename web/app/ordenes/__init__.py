"""Blueprint de ordenes de trabajo."""

from flask import Blueprint

bp = Blueprint("ordenes", __name__)

from . import routes  # noqa: E402,F401
