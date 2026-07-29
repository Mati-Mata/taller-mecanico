"""Flujos operativos de ordenes de trabajo."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation

from flask import abort, flash, redirect, render_template, request, url_for
from flask_login import current_user

from app.db import DatabaseError, call_procedure, fetch_all, fetch_one, mysql_error_message
from app.user import roles_required

from . import bp

TRANSICIONES_PERMITIDAS = {
    "ingresada": ("diagnostico", "cancelada"),
    "diagnostico": ("esperando_repuestos", "en_reparacion", "cancelada"),
    "esperando_repuestos": ("en_reparacion", "cancelada"),
    "en_reparacion": ("esperando_repuestos", "cancelada"),
    "finalizada": (),
    "cancelada": (),
}


def estados_siguientes(estado: str) -> tuple[str, ...]:
    return TRANSICIONES_PERMITIDAS.get(estado, ())


def _orden_autorizada(id_orden_trabajo: int) -> dict:
    orden = fetch_one(
        """
        SELECT
            ot.*,
            v.placa,
            v.marca,
            v.modelo,
            v.id_cliente,
            c.identificacion AS identificacion_cliente,
            COALESCE(c.razon_social, CONCAT_WS(' ', c.nombres, c.apellidos))
                AS nombre_cliente,
            CONCAT_WS(' ', u.nombres, u.apellidos) AS nombre_mecanico
        FROM orden_trabajo AS ot
        INNER JOIN vehiculo AS v ON v.id_vehiculo = ot.id_vehiculo
        INNER JOIN cliente AS c ON c.id_cliente = v.id_cliente
        INNER JOIN mecanico AS m ON m.id_mecanico = ot.id_mecanico
        INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
        WHERE ot.id_orden_trabajo = %s
        """,
        (id_orden_trabajo,),
    )
    if orden is None:
        abort(404)
    if (
        current_user.rol == "mecanico"
        and orden["id_mecanico"] != current_user.id_mecanico
    ):
        abort(403)
    return orden


@bp.get("/ordenes")
@roles_required("administrador", "asesor", "mecanico")
def index():
    estado = request.args.get("estado", "").strip()
    search = request.args.get("q", "").strip()
    pattern = f"%{search}%"
    params: tuple[object, ...] = (
        estado,
        estado,
        search,
        pattern,
        pattern,
        pattern,
        current_user.rol,
        current_user.id_mecanico,
    )

    ordenes = fetch_all(
        """
        SELECT
            ot.id_orden_trabajo,
            ot.estado,
            ot.descripcion_problema,
            ot.fecha_apertura,
            ot.fecha_finalizacion,
            v.placa,
            v.marca,
            v.modelo,
            COALESCE(c.razon_social, CONCAT_WS(' ', c.nombres, c.apellidos))
                AS nombre_cliente,
            CONCAT_WS(' ', u.nombres, u.apellidos) AS nombre_mecanico,
            COALESCE(SUM(d.subtotal), 0.00) AS total_estimado
        FROM orden_trabajo AS ot
        INNER JOIN vehiculo AS v ON v.id_vehiculo = ot.id_vehiculo
        INNER JOIN cliente AS c ON c.id_cliente = v.id_cliente
        INNER JOIN mecanico AS m ON m.id_mecanico = ot.id_mecanico
        INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
        LEFT JOIN detalle_orden AS d
            ON d.id_orden_trabajo = ot.id_orden_trabajo
        WHERE (%s = '' OR ot.estado = %s)
          AND (
              %s = ''
              OR v.placa LIKE %s
              OR ot.descripcion_problema LIKE %s
              OR COALESCE(
                    c.razon_social,
                    CONCAT_WS(' ', c.nombres, c.apellidos)
                 ) LIKE %s
          )
          AND (%s <> 'mecanico' OR ot.id_mecanico = %s)
        GROUP BY
            ot.id_orden_trabajo, ot.estado, ot.descripcion_problema,
            ot.fecha_apertura, ot.fecha_finalizacion, v.placa, v.marca,
            v.modelo, c.razon_social, c.nombres, c.apellidos, u.nombres,
            u.apellidos
        ORDER BY ot.fecha_apertura DESC
        """,
        params,
    )
    return render_template(
        "ordenes/index.html",
        ordenes=ordenes,
        estado=estado,
        search=search,
        estados=TRANSICIONES_PERMITIDAS,
    )


@bp.route("/ordenes/nueva", methods=["GET", "POST"])
@roles_required("administrador", "asesor")
def nueva():
    if request.method == "POST":
        try:
            descripcion = request.form.get("descripcion_problema", "").strip()
            kilometraje = int(request.form.get("kilometraje_ingreso", ""))
            if not descripcion or kilometraje < 0:
                raise ValueError
            result = call_procedure(
                "sp_crear_orden_trabajo",
                (
                    current_user.id_usuario,
                    int(request.form.get("id_vehiculo", "")),
                    int(request.form.get("id_mecanico", "")),
                    descripcion,
                    request.form.get("observacion", "").strip() or None,
                    kilometraje,
                    None,
                ),
            )
            flash("Orden de trabajo creada correctamente.", "success")
            return redirect(url_for("ordenes.detalle", id_orden_trabajo=result[-1]))
        except (TypeError, ValueError):
            flash("Selecciona vehiculo, mecanico y kilometraje validos.", "danger")
        except DatabaseError as exc:
            flash(mysql_error_message(exc), "danger")
        return redirect(url_for("ordenes.nueva"))

    vehiculos = fetch_all(
        """
        SELECT
            v.id_vehiculo,
            v.placa,
            v.marca,
            v.modelo,
            COALESCE(c.razon_social, CONCAT_WS(' ', c.nombres, c.apellidos))
                AS nombre_cliente
        FROM vehiculo AS v
        INNER JOIN cliente AS c ON c.id_cliente = v.id_cliente
        WHERE v.activo = 1 AND c.activo = 1
        ORDER BY v.placa
        """
    )
    mecanicos = fetch_all(
        """
        SELECT
            m.id_mecanico,
            CONCAT_WS(' ', u.nombres, u.apellidos) AS nombre_mecanico,
            m.especialidad,
            m.disponibilidad
        FROM mecanico AS m
        INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
        WHERE m.activo = 1
          AND u.activo = 1
          AND m.disponibilidad = 'disponible'
        ORDER BY u.apellidos, u.nombres
        """
    )
    return render_template(
        "ordenes/nueva.html",
        vehiculos=vehiculos,
        mecanicos=mecanicos,
        vehiculo_preseleccionado=request.args.get("vehiculo", type=int),
    )


@bp.get("/ordenes/<int:id_orden_trabajo>")
@roles_required("administrador", "asesor", "mecanico")
def detalle(id_orden_trabajo: int):
    orden = _orden_autorizada(id_orden_trabajo)
    detalles = fetch_all(
        """
        SELECT
            d.*,
            CASE
                WHEN d.id_servicio IS NOT NULL THEN 'servicio'
                ELSE 'repuesto'
            END AS tipo_concepto
        FROM detalle_orden AS d
        WHERE d.id_orden_trabajo = %s
        ORDER BY d.fecha_creacion, d.id_detalle_orden
        """,
        (id_orden_trabajo,),
    )
    historial = fetch_all(
        """
        SELECT
            h.*,
            CONCAT_WS(' ', u.nombres, u.apellidos) AS nombre_usuario
        FROM historial_estado_orden AS h
        INNER JOIN usuario AS u ON u.id_usuario = h.id_usuario
        WHERE h.id_orden_trabajo = %s
        ORDER BY h.fecha_cambio, h.id_historial_estado_orden
        """,
        (id_orden_trabajo,),
    )
    conceptos = fetch_all(
        """
        SELECT *
        FROM vw_precios_venta_vigentes
        ORDER BY tipo_concepto, nombre
        """
    )
    factura = fetch_one(
        """
        SELECT *
        FROM vw_facturas_estado_cobro
        WHERE id_orden_trabajo = %s
        """,
        (id_orden_trabajo,),
    )
    return render_template(
        "ordenes/detalle.html",
        orden=orden,
        detalles=detalles,
        historial=historial,
        conceptos=conceptos,
        factura=factura,
        estados_siguientes=estados_siguientes(orden["estado"]),
    )


@bp.post("/ordenes/<int:id_orden_trabajo>/diagnostico")
@roles_required("administrador", "asesor", "mecanico")
def actualizar_diagnostico(id_orden_trabajo: int):
    _orden_autorizada(id_orden_trabajo)
    diagnostico = request.form.get("diagnostico", "").strip()
    if not diagnostico:
        flash("El diagnostico es obligatorio.", "danger")
        return redirect(url_for("ordenes.detalle", id_orden_trabajo=id_orden_trabajo))
    try:
        call_procedure(
            "sp_actualizar_diagnostico_orden",
            (
                current_user.id_usuario,
                id_orden_trabajo,
                diagnostico,
                request.form.get("observacion", "").strip() or None,
                None,
            ),
        )
        flash("Diagnostico actualizado.", "success")
    except DatabaseError as exc:
        flash(mysql_error_message(exc), "danger")
    return redirect(url_for("ordenes.detalle", id_orden_trabajo=id_orden_trabajo))


@bp.post("/ordenes/<int:id_orden_trabajo>/detalles")
@roles_required("administrador", "asesor", "mecanico")
def agregar_detalle(id_orden_trabajo: int):
    _orden_autorizada(id_orden_trabajo)
    try:
        tipo = request.form.get("tipo_concepto", "").strip()
        id_concepto = int(request.form.get("id_concepto", ""))
        cantidad = Decimal(request.form.get("cantidad", ""))
        if tipo not in {"servicio", "repuesto"} or cantidad <= 0:
            raise ValueError
        call_procedure(
            "sp_agregar_detalle_orden",
            (
                current_user.id_usuario,
                id_orden_trabajo,
                tipo,
                id_concepto,
                cantidad,
                request.form.get("observacion", "").strip() or None,
                None,
            ),
        )
        flash("Concepto agregado a la orden.", "success")
    except (InvalidOperation, TypeError, ValueError):
        flash("Selecciona un concepto y una cantidad mayor que cero.", "danger")
    except DatabaseError as exc:
        flash(mysql_error_message(exc), "danger")
    return redirect(url_for("ordenes.detalle", id_orden_trabajo=id_orden_trabajo))


@bp.post("/ordenes/<int:id_orden_trabajo>/estado")
@roles_required("administrador", "asesor", "mecanico")
def cambiar_estado(id_orden_trabajo: int):
    orden = _orden_autorizada(id_orden_trabajo)
    estado_nuevo = request.form.get("estado", "").strip()
    if estado_nuevo not in estados_siguientes(orden["estado"]):
        flash("La transicion solicitada no esta permitida.", "danger")
        return redirect(url_for("ordenes.detalle", id_orden_trabajo=id_orden_trabajo))
    try:
        call_procedure(
            "sp_cambiar_estado_orden",
            (
                current_user.id_usuario,
                id_orden_trabajo,
                estado_nuevo,
                request.form.get("observacion", "").strip() or None,
                None,
            ),
        )
        flash("Estado de la orden actualizado.", "success")
    except DatabaseError as exc:
        flash(mysql_error_message(exc), "danger")
    return redirect(url_for("ordenes.detalle", id_orden_trabajo=id_orden_trabajo))


@bp.post("/ordenes/<int:id_orden_trabajo>/finalizar")
@roles_required("administrador", "asesor", "mecanico")
def finalizar(id_orden_trabajo: int):
    _orden_autorizada(id_orden_trabajo)
    try:
        call_procedure(
            "sp_finalizar_orden",
            (
                current_user.id_usuario,
                id_orden_trabajo,
                request.form.get("observacion", "").strip() or None,
                None,
            ),
        )
        flash("Orden finalizada e inventario descontado.", "success")
    except DatabaseError as exc:
        flash(mysql_error_message(exc), "danger")
    return redirect(url_for("ordenes.detalle", id_orden_trabajo=id_orden_trabajo))
