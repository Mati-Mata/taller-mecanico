"""Consultas y presentación del dashboard operativo."""

from typing import Any

from flask import flash, render_template
from flask_login import login_required

from app.db import DatabaseError, fetch_all, fetch_one

from . import bp


ACTIVE_ORDER_STATES = (
    "ingresada",
    "diagnostico",
    "esperando_repuestos",
    "en_reparacion",
)


def _count(query: str, params: tuple[Any, ...] = ()) -> int:
    row = fetch_one(query, params)
    return int(row["total"]) if row else 0


def _load_dashboard() -> dict[str, Any]:
    stats = {
        "ordenes_activas": _count(
            """
                SELECT COUNT(*) AS total
                FROM orden_trabajo
                WHERE estado IN (%s, %s, %s, %s)
            """,
            ACTIVE_ORDER_STATES,
        ),
        "ordenes_finalizadas": _count(
            """
                SELECT COUNT(*) AS total
                FROM orden_trabajo
                WHERE estado = %s
            """,
            ("finalizada",),
        ),
        "facturas_pendientes": _count(
            """
                SELECT COUNT(*) AS total
                FROM vw_facturas_estado_cobro
                WHERE estado_cobro = %s
            """,
            ("pendiente",),
        ),
        "repuestos_bajo_minimo": _count(
            """
                SELECT COUNT(*) AS total
                FROM repuesto
                WHERE activo = %s
                  AND stock_actual <= stock_minimo
            """,
            (1,),
        ),
        "mecanicos_activos": _count(
            """
                SELECT COUNT(*) AS total
                FROM mecanico AS m
                INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
                INNER JOIN rol AS r ON r.id_rol = u.id_rol
                WHERE m.activo = %s
                  AND u.activo = %s
                  AND r.activo = %s
                  AND r.nombre = %s
            """,
            (1, 1, 1, "mecanico"),
        ),
    }

    latest_orders = fetch_all(
        """
            SELECT
                ot.id_orden_trabajo,
                ot.estado,
                ot.fecha_apertura,
                v.placa,
                CONCAT_WS(' ', u.nombres, u.apellidos) AS mecanico
            FROM orden_trabajo AS ot
            INNER JOIN vehiculo AS v ON v.id_vehiculo = ot.id_vehiculo
            INNER JOIN mecanico AS m ON m.id_mecanico = ot.id_mecanico
            INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
            ORDER BY ot.fecha_apertura DESC, ot.id_orden_trabajo DESC
            LIMIT %s
        """,
        (8,),
    )

    invoices = fetch_all(
        """
            SELECT
                numero_factura,
                estado_factura,
                estado_cobro,
                fecha_emision,
                nombre_cliente,
                total,
                saldo
            FROM vw_facturas_estado_cobro
            ORDER BY fecha_emision DESC, id_factura DESC
            LIMIT %s
        """,
        (6,),
    )

    low_stock = fetch_all(
        """
            SELECT
                codigo,
                nombre,
                stock_actual,
                stock_minimo,
                unidad_medida
            FROM repuesto
            WHERE activo = %s
              AND stock_actual <= stock_minimo
            ORDER BY stock_actual ASC, nombre ASC
            LIMIT %s
        """,
        (1, 8),
    )

    return {
        "stats": stats,
        "latest_orders": latest_orders,
        "invoices": invoices,
        "low_stock": low_stock,
    }


@bp.get("")
@bp.get("/")
@login_required
def index():
    """Muestra métricas y actividad real de la base."""
    try:
        context = _load_dashboard()
    except DatabaseError:
        flash(
            "No fue posible cargar los indicadores desde MySQL.",
            "danger",
        )
        context = {
            "stats": {
                "ordenes_activas": 0,
                "ordenes_finalizadas": 0,
                "facturas_pendientes": 0,
                "repuestos_bajo_minimo": 0,
                "mecanicos_activos": 0,
            },
            "latest_orders": [],
            "invoices": [],
            "low_stock": [],
        }
    return render_template("dashboard/index.html", **context)
