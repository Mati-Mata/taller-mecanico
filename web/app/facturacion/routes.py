"""Flujos de facturacion, cobros y anulaciones administrativas."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal, InvalidOperation

from flask import abort, flash, redirect, render_template, request, url_for
from flask_login import current_user

from app.db import DatabaseError, call_procedure, fetch_all, fetch_one, mysql_error_message
from app.user import roles_required

from . import bp


def _factura_existente(id_factura: int) -> dict:
    factura = fetch_one(
        "SELECT * FROM vw_facturas_estado_cobro WHERE id_factura = %s",
        (id_factura,),
    )
    if factura is None:
        abort(404)
    return factura


@bp.get("/facturas")
@roles_required("administrador", "asesor")
def index():
    estado = request.args.get("estado", "").strip()
    cobro = request.args.get("cobro", "").strip()
    search = request.args.get("q", "").strip()
    pattern = f"%{search}%"
    facturas = fetch_all(
        """
        SELECT *
        FROM vw_facturas_estado_cobro
        WHERE (%s = '' OR estado_factura = %s)
          AND (%s = '' OR estado_cobro = %s)
          AND (
              %s = ''
              OR numero_factura LIKE %s
              OR identificacion_cliente LIKE %s
              OR nombre_cliente LIKE %s
              OR placa_vehiculo LIKE %s
          )
        ORDER BY fecha_emision DESC, id_factura DESC
        """,
        (estado, estado, cobro, cobro, search, pattern, pattern, pattern, pattern),
    )
    return render_template(
        "facturacion/index.html",
        facturas=facturas,
        estado=estado,
        cobro=cobro,
        search=search,
    )


@bp.get("/facturas/<int:id_factura>")
@roles_required("administrador", "asesor")
def detalle(id_factura: int):
    factura = _factura_existente(id_factura)
    detalles = fetch_all(
        """
        SELECT * FROM detalle_factura
        WHERE id_factura = %s
        ORDER BY id_detalle_factura
        """,
        (id_factura,),
    )
    pagos = fetch_all(
        "SELECT * FROM pago WHERE id_factura = %s ORDER BY fecha_pago, id_pago",
        (id_factura,),
    )
    return render_template(
        "facturacion/detalle.html",
        factura=factura,
        detalles=detalles,
        pagos=pagos,
    )


@bp.post("/ordenes/<int:id_orden_trabajo>/generar-factura")
@roles_required("administrador", "asesor")
def generar(id_orden_trabajo: int):
    try:
        result = call_procedure(
            "sp_generar_factura",
            (current_user.id_usuario, id_orden_trabajo, None),
        )
        flash("Factura generada correctamente.", "success")
        return redirect(url_for("facturacion.detalle", id_factura=result[-1]))
    except DatabaseError as exc:
        flash(mysql_error_message(exc), "danger")
        return redirect(url_for("ordenes.detalle", id_orden_trabajo=id_orden_trabajo))


@bp.post("/facturas/<int:id_factura>/registrar-pago")
@roles_required("administrador", "asesor")
def registrar_pago(id_factura: int):
    _factura_existente(id_factura)
    try:
        monto = Decimal(request.form.get("monto", ""))
        fecha_texto = request.form.get("fecha_pago", "").strip()
        fecha_pago = datetime.fromisoformat(fecha_texto) if fecha_texto else None
        metodo = request.form.get("metodo_pago", "").strip()
        referencia = request.form.get("referencia", "").strip() or None
        if (
            monto <= 0
            or metodo not in {"efectivo", "tarjeta", "transferencia"}
            or (metodo in {"tarjeta", "transferencia"} and not referencia)
        ):
            raise ValueError
        call_procedure(
            "sp_registrar_pago",
            (
                current_user.id_usuario,
                id_factura,
                monto,
                metodo,
                referencia,
                fecha_pago,
                None,
            ),
        )
        flash("Pago registrado correctamente.", "success")
    except (InvalidOperation, TypeError, ValueError):
        flash("Completa monto, metodo y fecha con valores validos.", "danger")
    except DatabaseError as exc:
        flash(mysql_error_message(exc), "danger")
    return redirect(url_for("facturacion.detalle", id_factura=id_factura))


@bp.post("/facturas/<int:id_factura>/anular")
@roles_required("administrador")
def anular(id_factura: int):
    _factura_existente(id_factura)
    motivo = request.form.get("motivo", "").strip()
    if not motivo:
        flash("El motivo de anulacion es obligatorio.", "danger")
        return redirect(url_for("facturacion.detalle", id_factura=id_factura))
    try:
        call_procedure(
            "sp_anular_factura",
            (
                current_user.id_usuario,
                id_factura,
                motivo,
                None,
            ),
        )
        flash("Factura anulada.", "success")
    except DatabaseError as exc:
        flash(mysql_error_message(exc), "danger")
    return redirect(url_for("facturacion.detalle", id_factura=id_factura))


@bp.post("/pagos/<int:id_pago>/anular")
@roles_required("administrador")
def anular_pago(id_pago: int):
    pago = fetch_one("SELECT id_factura FROM pago WHERE id_pago = %s", (id_pago,))
    if pago is None:
        abort(404)
    motivo = request.form.get("motivo", "").strip()
    if not motivo:
        flash("El motivo de anulacion es obligatorio.", "danger")
        return redirect(url_for("facturacion.detalle", id_factura=pago["id_factura"]))
    try:
        call_procedure(
            "sp_anular_pago",
            (
                current_user.id_usuario,
                id_pago,
                motivo,
                None,
            ),
        )
        flash("Pago anulado.", "success")
    except DatabaseError as exc:
        flash(mysql_error_message(exc), "danger")
    return redirect(url_for("facturacion.detalle", id_factura=pago["id_factura"]))
