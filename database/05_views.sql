-- Fase 4: vistas representativas y seguras para consultas del taller.
-- Se ejecuta después de aplicar tablas, restricciones e índices.

USE taller_mecanico;

-- Catálogo unificado de precios de venta vigentes para servicios y repuestos
-- activos. Expone únicamente la información comercial necesaria.
CREATE OR REPLACE
    ALGORITHM = UNDEFINED
    SQL SECURITY INVOKER
VIEW vw_precios_venta_vigentes AS
    SELECT
        'servicio' AS tipo_concepto,
        s.id_servicio AS id_concepto,
        s.codigo AS codigo,
        s.nombre AS nombre,
        hp.precio_venta AS precio_venta,
        hp.fecha_inicio AS fecha_inicio
    FROM servicio AS s
    INNER JOIN historial_precio AS hp
        ON hp.id_servicio = s.id_servicio
    WHERE hp.fecha_fin IS NULL
      AND s.activo = 1

    UNION ALL

    SELECT
        'repuesto' AS tipo_concepto,
        r.id_repuesto AS id_concepto,
        r.codigo AS codigo,
        r.nombre AS nombre,
        hp.precio_venta AS precio_venta,
        hp.fecha_inicio AS fecha_inicio
    FROM repuesto AS r
    INNER JOIN historial_precio AS hp
        ON hp.id_repuesto = r.id_repuesto
    WHERE hp.fecha_fin IS NULL
      AND r.activo = 1;

-- Historial de mantenimiento con una fila por orden, datos del vehículo,
-- propietario, mecánico y resumen monetario de sus detalles.
CREATE OR REPLACE
    ALGORITHM = UNDEFINED
    SQL SECURITY INVOKER
VIEW vw_historial_vehiculo AS
    SELECT
        ot.id_orden_trabajo AS id_orden_trabajo,
        v.id_vehiculo AS id_vehiculo,
        v.placa AS placa,
        v.marca AS marca,
        v.modelo AS modelo,
        v.anio AS anio,
        ot.kilometraje_ingreso AS kilometraje_ingreso,
        c.id_cliente AS id_cliente,
        c.identificacion AS identificacion_cliente,
        CASE
            WHEN c.tipo_cliente = 'persona'
                THEN CONCAT_WS(' ', c.nombres, c.apellidos)
            WHEN c.tipo_cliente = 'empresa'
                THEN c.razon_social
        END AS nombre_cliente,
        m.id_mecanico AS id_mecanico,
        CONCAT_WS(' ', u.nombres, u.apellidos) AS nombre_mecanico,
        ot.estado AS estado,
        ot.descripcion_problema AS descripcion_problema,
        ot.diagnostico AS diagnostico,
        ot.observacion AS observacion,
        ot.fecha_apertura AS fecha_apertura,
        ot.fecha_finalizacion AS fecha_finalizacion,
        COALESCE(rd.cantidad_detalles, 0) AS cantidad_detalles,
        COALESCE(rd.total_estimado, 0.00) AS total_estimado
    FROM orden_trabajo AS ot
    INNER JOIN vehiculo AS v
        ON v.id_vehiculo = ot.id_vehiculo
    INNER JOIN cliente AS c
        ON c.id_cliente = v.id_cliente
    INNER JOIN mecanico AS m
        ON m.id_mecanico = ot.id_mecanico
    INNER JOIN usuario AS u
        ON u.id_usuario = m.id_usuario
    LEFT JOIN (
        SELECT
            id_orden_trabajo,
            COUNT(*) AS cantidad_detalles,
            SUM(subtotal) AS total_estimado
        FROM detalle_orden
        GROUP BY id_orden_trabajo
    ) AS rd
        ON rd.id_orden_trabajo = ot.id_orden_trabajo;

-- Órdenes históricas y activas asignadas a cada mecánico, junto con su carga
-- operativa actual, capacidad remanente y total estimado por orden.
CREATE OR REPLACE
    ALGORITHM = UNDEFINED
    SQL SECURITY INVOKER
VIEW vw_ordenes_mecanico AS
    SELECT
        m.id_mecanico AS id_mecanico,
        u.id_usuario AS id_usuario_mecanico,
        CONCAT_WS(' ', u.nombres, u.apellidos) AS nombre_mecanico,
        m.especialidad AS especialidad,
        m.nivel AS nivel,
        m.disponibilidad AS disponibilidad,
        m.maximo_ordenes_activas AS maximo_ordenes_activas,
        COALESCE(ca.ordenes_activas_actuales, 0)
            AS ordenes_activas_actuales,
        GREATEST(
            CAST(m.maximo_ordenes_activas AS SIGNED)
                - COALESCE(ca.ordenes_activas_actuales, 0),
            0
        ) AS capacidad_disponible,
        ot.id_orden_trabajo AS id_orden_trabajo,
        ot.estado AS estado_orden,
        CASE
            WHEN ot.estado IN (
                'ingresada',
                'diagnostico',
                'esperando_repuestos',
                'en_reparacion'
            ) THEN 1
            ELSE 0
        END AS es_orden_activa,
        ot.fecha_apertura AS fecha_apertura,
        v.placa AS placa,
        CASE
            WHEN v.id_vehiculo IS NULL THEN NULL
            ELSE CONCAT_WS(' ', v.marca, v.modelo)
        END AS vehiculo,
        CASE
            WHEN c.tipo_cliente = 'persona'
                THEN CONCAT_WS(' ', c.nombres, c.apellidos)
            WHEN c.tipo_cliente = 'empresa'
                THEN c.razon_social
        END AS nombre_cliente,
        COALESCE(tot.total_estimado, 0.00) AS total_estimado
    FROM mecanico AS m
    INNER JOIN usuario AS u
        ON u.id_usuario = m.id_usuario
    LEFT JOIN orden_trabajo AS ot
        ON ot.id_mecanico = m.id_mecanico
    LEFT JOIN vehiculo AS v
        ON v.id_vehiculo = ot.id_vehiculo
    LEFT JOIN cliente AS c
        ON c.id_cliente = v.id_cliente
    LEFT JOIN (
        SELECT
            id_mecanico,
            COUNT(*) AS ordenes_activas_actuales
        FROM orden_trabajo
        WHERE estado IN (
            'ingresada',
            'diagnostico',
            'esperando_repuestos',
            'en_reparacion'
        )
        GROUP BY id_mecanico
    ) AS ca
        ON ca.id_mecanico = m.id_mecanico
    LEFT JOIN (
        SELECT
            id_orden_trabajo,
            SUM(subtotal) AS total_estimado
        FROM detalle_orden
        GROUP BY id_orden_trabajo
    ) AS tot
        ON tot.id_orden_trabajo = ot.id_orden_trabajo;

-- Facturas con número visible derivado, pagos registrados agregados, saldo
-- defensivo y estado de cobro calculado.
CREATE OR REPLACE
    ALGORITHM = UNDEFINED
    SQL SECURITY INVOKER
VIEW vw_facturas_estado_cobro AS
    SELECT
        f.id_factura AS id_factura,
        CONCAT('FAC-', LPAD(f.id_factura, 8, '0')) AS numero_factura,
        f.id_orden_trabajo AS id_orden_trabajo,
        f.estado AS estado_factura,
        CASE
            WHEN f.estado = 'anulada' THEN 'anulada'
            WHEN COALESCE(rp.monto_pagado, 0.00) >= f.total THEN 'pagada'
            ELSE 'pendiente'
        END AS estado_cobro,
        f.fecha_emision AS fecha_emision,
        f.identificacion_cliente AS identificacion_cliente,
        f.nombre_cliente AS nombre_cliente,
        f.direccion_cliente AS direccion_cliente,
        f.placa_vehiculo AS placa_vehiculo,
        f.subtotal AS subtotal,
        f.porcentaje_iva AS porcentaje_iva,
        f.valor_iva AS valor_iva,
        f.total AS total,
        COALESCE(rp.monto_pagado, 0.00) AS monto_pagado,
        CASE
            WHEN f.estado = 'anulada' THEN 0.00
            ELSE GREATEST(
                f.total - COALESCE(rp.monto_pagado, 0.00),
                0.00
            )
        END AS saldo,
        COALESCE(rp.cantidad_pagos_registrados, 0)
            AS cantidad_pagos_registrados
    FROM factura AS f
    LEFT JOIN (
        SELECT
            id_factura,
            SUM(monto) AS monto_pagado,
            COUNT(*) AS cantidad_pagos_registrados
        FROM pago
        WHERE estado = 'registrado'
        GROUP BY id_factura
    ) AS rp
        ON rp.id_factura = f.id_factura;
