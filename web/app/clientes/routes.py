"""Flujos de clientes, vehiculos e historial operativo."""

from __future__ import annotations

from flask import abort, flash, redirect, render_template, request, url_for
from flask_login import current_user

from app.db import DatabaseError, call_procedure, fetch_all, fetch_one, mysql_error_message
from app.user import roles_required

from . import bp


def _optional_text(name: str) -> str | None:
    value = request.form.get(name, "").strip()
    return value or None


@bp.get("/clientes")
@roles_required("administrador", "asesor")
def index():
    search = request.args.get("q", "").strip()
    pattern = f"%{search}%"
    clientes = fetch_all(
        """
        SELECT
            c.id_cliente,
            c.tipo_cliente,
            c.identificacion,
            COALESCE(c.razon_social, CONCAT_WS(' ', c.nombres, c.apellidos))
                AS nombre_cliente,
            c.telefono,
            c.correo,
            c.activo,
            COUNT(v.id_vehiculo) AS cantidad_vehiculos
        FROM cliente AS c
        LEFT JOIN vehiculo AS v ON v.id_cliente = c.id_cliente
        WHERE (
            %s = ''
            OR c.identificacion LIKE %s
            OR COALESCE(c.nombres, '') LIKE %s
            OR COALESCE(c.apellidos, '') LIKE %s
            OR COALESCE(c.razon_social, '') LIKE %s
            OR c.telefono LIKE %s
            OR COALESCE(v.placa, '') LIKE %s
        )
        GROUP BY
            c.id_cliente, c.tipo_cliente, c.identificacion, c.razon_social,
            c.nombres, c.apellidos, c.telefono, c.correo, c.activo
        ORDER BY c.fecha_creacion DESC, c.id_cliente DESC
        """,
        (search, pattern, pattern, pattern, pattern, pattern, pattern),
    )
    return render_template("clientes/index.html", clientes=clientes, search=search)


@bp.route("/clientes/nuevo", methods=["GET", "POST"])
@roles_required("administrador", "asesor")
def nuevo():
    if request.method == "POST":
        try:
            tipo_cliente = request.form.get("tipo_cliente", "").strip()
            identificacion = request.form.get("identificacion", "").strip()
            telefono = request.form.get("telefono", "").strip()
            placa = request.form.get("placa", "").strip()
            marca = request.form.get("marca", "").strip()
            modelo = request.form.get("modelo", "").strip()
            anio_texto = request.form.get("anio", "").strip()
            kilometraje = int(request.form.get("kilometraje_actual", "0"))
            if (
                not identificacion
                or not telefono
                or not placa
                or not marca
                or not modelo
                or kilometraje < 0
                or (
                    tipo_cliente == "persona"
                    and (not _optional_text("nombres") or not _optional_text("apellidos"))
                )
                or (tipo_cliente == "empresa" and not _optional_text("razon_social"))
            ):
                raise ValueError
            result = call_procedure(
                "sp_crear_cliente_vehiculo",
                (
                    current_user.id_usuario,
                    tipo_cliente,
                    request.form.get("tipo_identificacion", "").strip(),
                    identificacion,
                    _optional_text("nombres"),
                    _optional_text("apellidos"),
                    _optional_text("razon_social"),
                    telefono,
                    _optional_text("correo"),
                    _optional_text("direccion"),
                    placa,
                    _optional_text("numero_chasis"),
                    marca,
                    modelo,
                    int(anio_texto) if anio_texto else None,
                    _optional_text("color"),
                    kilometraje,
                    None,
                    None,
                ),
            )
            flash("Cliente y vehiculo creados correctamente.", "success")
            return redirect(url_for("clientes.detalle", id_cliente=result[-2]))
        except (TypeError, ValueError):
            flash("Completa los campos obligatorios con valores validos.", "danger")
        except DatabaseError as exc:
            flash(mysql_error_message(exc), "danger")
        return redirect(url_for("clientes.nuevo"))

    return render_template("clientes/nuevo.html")


@bp.get("/clientes/<int:id_cliente>")
@roles_required("administrador", "asesor")
def detalle(id_cliente: int):
    cliente = fetch_one(
        """
        SELECT
            c.*,
            COALESCE(c.razon_social, CONCAT_WS(' ', c.nombres, c.apellidos))
                AS nombre_cliente
        FROM cliente AS c
        WHERE c.id_cliente = %s
        """,
        (id_cliente,),
    )
    if cliente is None:
        abort(404)
    vehiculos = fetch_all(
        "SELECT * FROM vehiculo WHERE id_cliente = %s ORDER BY activo DESC, placa",
        (id_cliente,),
    )
    historial = fetch_all(
        """
        SELECT *
        FROM vw_historial_vehiculo
        WHERE id_cliente = %s
        ORDER BY fecha_apertura DESC
        """,
        (id_cliente,),
    )
    return render_template(
        "clientes/detalle.html",
        cliente=cliente,
        vehiculos=vehiculos,
        historial=historial,
    )


@bp.get("/vehiculos/<int:id_vehiculo>")
@roles_required("administrador", "asesor")
def vehiculo(id_vehiculo: int):
    vehiculo_actual = fetch_one(
        """
        SELECT
            v.*,
            c.identificacion,
            COALESCE(c.razon_social, CONCAT_WS(' ', c.nombres, c.apellidos))
                AS nombre_cliente
        FROM vehiculo AS v
        INNER JOIN cliente AS c ON c.id_cliente = v.id_cliente
        WHERE v.id_vehiculo = %s
        """,
        (id_vehiculo,),
    )
    if vehiculo_actual is None:
        abort(404)
    historial = fetch_all(
        """
        SELECT *
        FROM vw_historial_vehiculo
        WHERE id_vehiculo = %s
        ORDER BY fecha_apertura DESC
        """,
        (id_vehiculo,),
    )
    return render_template(
        "clientes/vehiculo.html",
        vehiculo=vehiculo_actual,
        historial=historial,
    )
