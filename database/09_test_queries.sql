-- Batería integral y reproducible de pruebas del taller mecánico.
-- Requiere ejecutar previamente 01_create_database.sql hasta 08_seed_data.sql.
-- Todas las operaciones de prueba se revierten y no alteran la semilla.

USE taller_mecanico;

SET @app_id_usuario = NULL;
SET @app_origen = NULL;
SET @app_motivo = NULL;

-- ===========================================================================
-- SECCIÓN 1: VERIFICACIÓN ESTRUCTURAL
-- ===========================================================================

SELECT
    'tablas_base' AS objeto,
    15 AS esperado,
    COUNT(*) AS obtenido,
    IF(COUNT(*) = 15, 'PASS', 'FAIL') AS resultado
FROM information_schema.tables
WHERE table_schema = 'taller_mecanico'
  AND table_type = 'BASE TABLE'
UNION ALL
SELECT
    'vistas',
    4,
    COUNT(*),
    IF(COUNT(*) = 4, 'PASS', 'FAIL')
FROM information_schema.views
WHERE table_schema = 'taller_mecanico'
UNION ALL
SELECT
    'procedimientos',
    11,
    COUNT(*),
    IF(COUNT(*) = 11, 'PASS', 'FAIL')
FROM information_schema.routines
WHERE routine_schema = 'taller_mecanico'
  AND routine_type = 'PROCEDURE'
UNION ALL
SELECT
    'triggers',
    40,
    COUNT(*),
    IF(COUNT(*) = 40, 'PASS', 'FAIL')
FROM information_schema.triggers
WHERE trigger_schema = 'taller_mecanico'
UNION ALL
SELECT
    'claves_foraneas',
    24,
    COUNT(*),
    IF(COUNT(*) = 24, 'PASS', 'FAIL')
FROM information_schema.table_constraints
WHERE constraint_schema = 'taller_mecanico'
  AND constraint_type = 'FOREIGN KEY'
UNION ALL
SELECT
    'restricciones_unique',
    12,
    COUNT(*),
    IF(COUNT(*) = 12, 'PASS', 'FAIL')
FROM information_schema.table_constraints
WHERE constraint_schema = 'taller_mecanico'
  AND constraint_type = 'UNIQUE'
UNION ALL
SELECT
    'restricciones_check',
    95,
    COUNT(*),
    IF(COUNT(*) = 95, 'PASS', 'FAIL')
FROM information_schema.table_constraints
WHERE constraint_schema = 'taller_mecanico'
  AND constraint_type = 'CHECK'
UNION ALL
SELECT
    'indices_fase_3',
    12,
    COUNT(DISTINCT index_name),
    IF(COUNT(DISTINCT index_name) = 12, 'PASS', 'FAIL')
FROM information_schema.statistics
WHERE table_schema = 'taller_mecanico'
  AND index_name LIKE 'idx\\_%';

SELECT table_name AS vista
FROM information_schema.views
WHERE table_schema = 'taller_mecanico'
ORDER BY table_name;

SELECT routine_name AS procedimiento
FROM information_schema.routines
WHERE routine_schema = 'taller_mecanico'
  AND routine_type = 'PROCEDURE'
ORDER BY routine_name;

WITH distribucion_esperada AS (
    SELECT 'BEFORE' AS timing, 'INSERT' AS evento, 5 AS esperado
    UNION ALL SELECT 'BEFORE', 'UPDATE', 10
    UNION ALL SELECT 'BEFORE', 'DELETE', 10
    UNION ALL SELECT 'AFTER', 'INSERT', 4
    UNION ALL SELECT 'AFTER', 'UPDATE', 11
    UNION ALL SELECT 'AFTER', 'DELETE', 0
),
distribucion_real AS (
    SELECT
        action_timing AS timing,
        event_manipulation AS evento,
        COUNT(*) AS obtenido
    FROM information_schema.triggers
    WHERE trigger_schema = 'taller_mecanico'
    GROUP BY action_timing, event_manipulation
)
SELECT
    e.timing,
    e.evento,
    e.esperado,
    COALESCE(r.obtenido, 0) AS obtenido,
    IF(COALESCE(r.obtenido, 0) = e.esperado, 'PASS', 'FAIL') AS resultado
FROM distribucion_esperada AS e
LEFT JOIN distribucion_real AS r
  ON r.timing = e.timing
 AND r.evento = e.evento
ORDER BY
    FIELD(e.timing, 'BEFORE', 'AFTER'),
    FIELD(e.evento, 'INSERT', 'UPDATE', 'DELETE');

-- ===========================================================================
-- SECCIÓN 2: VERIFICACIÓN DE DATOS SEMILLA
-- ===========================================================================

SELECT
    'rol' AS tabla,
    3 AS esperado,
    COUNT(*) AS obtenido,
    IF(COUNT(*) = 3, 'PASS', 'FAIL') AS resultado
FROM rol
UNION ALL
SELECT 'usuario', 4, COUNT(*), IF(COUNT(*) = 4, 'PASS', 'FAIL') FROM usuario
UNION ALL
SELECT 'mecanico', 2, COUNT(*), IF(COUNT(*) = 2, 'PASS', 'FAIL') FROM mecanico
UNION ALL
SELECT 'cliente', 3, COUNT(*), IF(COUNT(*) = 3, 'PASS', 'FAIL') FROM cliente
UNION ALL
SELECT 'vehiculo', 3, COUNT(*), IF(COUNT(*) = 3, 'PASS', 'FAIL') FROM vehiculo
UNION ALL
SELECT 'servicio', 5, COUNT(*), IF(COUNT(*) = 5, 'PASS', 'FAIL') FROM servicio
UNION ALL
SELECT 'repuesto', 6, COUNT(*), IF(COUNT(*) = 6, 'PASS', 'FAIL') FROM repuesto
UNION ALL
SELECT
    'historial_precio',
    12,
    COUNT(*),
    IF(COUNT(*) = 12, 'PASS', 'FAIL')
FROM historial_precio
UNION ALL
SELECT
    'orden_trabajo',
    5,
    COUNT(*),
    IF(COUNT(*) = 5, 'PASS', 'FAIL')
FROM orden_trabajo
UNION ALL
SELECT
    'historial_estado_orden',
    17,
    COUNT(*),
    IF(COUNT(*) = 17, 'PASS', 'FAIL')
FROM historial_estado_orden
UNION ALL
SELECT
    'detalle_orden',
    7,
    COUNT(*),
    IF(COUNT(*) = 7, 'PASS', 'FAIL')
FROM detalle_orden
UNION ALL
SELECT 'factura', 3, COUNT(*), IF(COUNT(*) = 3, 'PASS', 'FAIL') FROM factura
UNION ALL
SELECT
    'detalle_factura',
    5,
    COUNT(*),
    IF(COUNT(*) = 5, 'PASS', 'FAIL')
FROM detalle_factura
UNION ALL
SELECT 'pago', 1, COUNT(*), IF(COUNT(*) = 1, 'PASS', 'FAIL') FROM pago
UNION ALL
SELECT
    'auditoria',
    46,
    COUNT(*),
    IF(COUNT(*) = 46, 'PASS', 'FAIL')
FROM auditoria;

SELECT
    estado,
    COUNT(*) AS cantidad,
    CASE estado
        WHEN 'finalizada' THEN 3
        WHEN 'esperando_repuestos' THEN 1
        WHEN 'cancelada' THEN 1
        ELSE 0
    END AS esperado
FROM orden_trabajo
GROUP BY estado
ORDER BY estado;

SELECT
    COUNT(*) AS precios_totales,
    SUM(fecha_fin IS NULL) AS precios_vigentes,
    SUM(fecha_fin IS NOT NULL) AS precios_cerrados,
    IF(
        COUNT(*) = 12
        AND SUM(fecha_fin IS NULL) = 11
        AND SUM(fecha_fin IS NOT NULL) = 1,
        'PASS',
        'FAIL'
    ) AS resultado
FROM historial_precio;

-- ===========================================================================
-- SECCIÓN 3: COMPROBACIONES DE INVARIANTES
-- ===========================================================================

-- Resultado esperado: 0 filas
SELECT id_servicio, COUNT(*) AS precios_vigentes
FROM historial_precio
WHERE id_servicio IS NOT NULL
  AND fecha_fin IS NULL
GROUP BY id_servicio
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas
SELECT id_repuesto, COUNT(*) AS precios_vigentes
FROM historial_precio
WHERE id_repuesto IS NOT NULL
  AND fecha_fin IS NULL
GROUP BY id_repuesto
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas
SELECT *
FROM historial_precio
WHERE (id_servicio IS NULL AND id_repuesto IS NULL)
   OR (id_servicio IS NOT NULL AND id_repuesto IS NOT NULL);

-- Resultado esperado: 0 filas
SELECT det.*
FROM detalle_orden AS det
INNER JOIN historial_precio AS hp
        ON hp.id_historial_precio = det.id_historial_precio
WHERE (det.id_servicio IS NOT NULL AND (
           NOT (det.id_servicio <=> hp.id_servicio)
           OR hp.id_repuesto IS NOT NULL
      ))
   OR (det.id_repuesto IS NOT NULL AND (
           NOT (det.id_repuesto <=> hp.id_repuesto)
           OR hp.id_servicio IS NOT NULL
      ));

-- Resultado esperado: 0 filas
SELECT det.*
FROM detalle_orden AS det
INNER JOIN historial_precio AS hp
        ON hp.id_historial_precio = det.id_historial_precio
WHERE NOT (det.precio_unitario <=> hp.precio_venta);

-- Resultado esperado: 0 filas
SELECT *
FROM detalle_orden
WHERE subtotal <> ROUND(cantidad * precio_unitario, 2);

-- Resultado esperado: 0 filas
SELECT f.id_factura, f.subtotal, COALESCE(df.subtotal_detalles, 0.00)
FROM factura AS f
LEFT JOIN (
    SELECT id_factura, SUM(subtotal) AS subtotal_detalles
    FROM detalle_factura
    GROUP BY id_factura
) AS df ON df.id_factura = f.id_factura
WHERE NOT (f.subtotal <=> df.subtotal_detalles);

-- Resultado esperado: 0 filas
SELECT *
FROM factura
WHERE porcentaje_iva <> 15.00
   OR valor_iva <> ROUND(subtotal * 15.00 / 100, 2)
   OR total <> subtotal + valor_iva;

-- Resultado esperado: 0 filas
SELECT df.*
FROM detalle_factura AS df
INNER JOIN detalle_orden AS det
        ON det.id_detalle_orden = df.id_detalle_orden
LEFT JOIN servicio AS s ON s.id_servicio = det.id_servicio
LEFT JOIN repuesto AS r ON r.id_repuesto = det.id_repuesto
WHERE NOT (
          df.tipo_concepto
          <=> CASE
                  WHEN det.id_servicio IS NOT NULL THEN 'servicio'
                  ELSE 'repuesto'
              END
      )
   OR NOT (
          df.codigo_concepto
          <=> CASE
                  WHEN det.id_servicio IS NOT NULL THEN s.codigo
                  ELSE r.codigo
              END
      )
   OR NOT (df.descripcion_concepto <=> det.descripcion_concepto)
   OR NOT (df.cantidad <=> det.cantidad)
   OR NOT (df.precio_unitario <=> det.precio_unitario)
   OR NOT (df.subtotal <=> det.subtotal);

-- Resultado esperado: 0 filas
SELECT id_factura, COUNT(*) AS pagos_registrados
FROM pago
WHERE estado = 'registrado'
GROUP BY id_factura
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas
SELECT p.*
FROM pago AS p
INNER JOIN factura AS f ON f.id_factura = p.id_factura
WHERE p.estado = 'registrado'
  AND p.monto <> f.total;

-- Resultado esperado: 0 filas
SELECT ot.*
FROM orden_trabajo AS ot
LEFT JOIN (
    SELECT id_orden_trabajo, COUNT(*) AS cantidad_detalles
    FROM detalle_orden
    GROUP BY id_orden_trabajo
) AS det ON det.id_orden_trabajo = ot.id_orden_trabajo
WHERE ot.estado = 'finalizada'
  AND (
      ot.diagnostico IS NULL
      OR TRIM(ot.diagnostico) = ''
      OR COALESCE(det.cantidad_detalles, 0) = 0
      OR ot.inventario_descontado <> 1
      OR ot.fecha_finalizacion IS NULL
  );

-- Resultado esperado: 0 filas
SELECT *
FROM orden_trabajo
WHERE estado <> 'finalizada'
  AND (
      inventario_descontado = 1
      OR fecha_finalizacion IS NOT NULL
  );

-- Resultado esperado: 0 filas
SELECT *
FROM repuesto
WHERE stock_actual < 0;

-- Resultado esperado: 0 filas
SELECT m.*, u.id_rol, r.nombre AS rol, r.activo AS rol_activo
FROM mecanico AS m
INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
INNER JOIN rol AS r ON r.id_rol = u.id_rol
WHERE m.activo = 1
  AND (
      u.activo <> 1
      OR r.activo <> 1
      OR r.nombre <> 'mecanico'
  );

-- Resultado esperado: 0 filas
SELECT *
FROM auditoria
WHERE JSON_CONTAINS_PATH(datos_anteriores, 'one', '$.password_hash') = 1
   OR JSON_CONTAINS_PATH(datos_nuevos, 'one', '$.password_hash') = 1;

-- ===========================================================================
-- SECCIÓN 4: RESULTADOS FUNCIONALES
-- ===========================================================================

SELECT *
FROM vw_precios_venta_vigentes
ORDER BY tipo_concepto, codigo;

SELECT *
FROM vw_historial_vehiculo
ORDER BY placa, fecha_apertura, id_orden_trabajo;

SELECT *
FROM vw_ordenes_mecanico
ORDER BY nombre_mecanico, fecha_apertura, id_orden_trabajo;

SELECT *
FROM vw_facturas_estado_cobro
ORDER BY id_factura;

SELECT
    numero_factura,
    estado_cobro,
    total,
    saldo,
    CASE numero_factura
        WHEN 'FAC-00000001' THEN IF(
            estado_cobro = 'pagada'
            AND total = 102.35
            AND saldo = 0.00,
            'PASS',
            'FAIL'
        )
        WHEN 'FAC-00000002' THEN IF(
            estado_cobro = 'pendiente'
            AND total = 92.00
            AND saldo = 92.00,
            'PASS',
            'FAIL'
        )
        WHEN 'FAC-00000003' THEN IF(
            estado_cobro = 'anulada'
            AND total = 46.00
            AND saldo = 0.00,
            'PASS',
            'FAIL'
        )
        ELSE 'NO_ESPERADA'
    END AS resultado
FROM vw_facturas_estado_cobro
ORDER BY id_factura;

SELECT
    codigo,
    nombre,
    stock_actual,
    stock_minimo,
    CASE codigo
        WHEN 'REP-ACE-5W30' THEN IF(stock_actual = 96.00, 'PASS', 'FAIL')
        WHEN 'REP-FILT-ACE' THEN IF(stock_actual = 29.00, 'PASS', 'FAIL')
        WHEN 'REP-BOMB-12V' THEN IF(stock_actual = 40.00, 'PASS', 'FAIL')
        WHEN 'REP-PAST-FRE' THEN IF(stock_actual = 24.00, 'PASS', 'FAIL')
        WHEN 'REP-CORREA' THEN IF(stock_actual = 18.00, 'PASS', 'FAIL')
        WHEN 'REP-LIQ-FRE' THEN IF(stock_actual = 50.00, 'PASS', 'FAIL')
        ELSE 'NO_ESPERADO'
    END AS resultado
FROM repuesto
ORDER BY codigo;

SELECT tabla_afectada, accion, COUNT(*) AS cantidad
FROM auditoria
GROUP BY tabla_afectada, accion
ORDER BY tabla_afectada, accion;

-- ===========================================================================
-- SECCIÓN 5: SEGURIDAD DE AUDITORÍA
-- ===========================================================================

SELECT
    46 AS esperado,
    COUNT(*) AS obtenido,
    IF(COUNT(*) = 46, 'PASS', 'FAIL') AS resultado
FROM auditoria;

SELECT
    COUNT(*) AS json_con_password_hash,
    IF(COUNT(*) = 0, 'PASS', 'FAIL') AS resultado
FROM auditoria
WHERE JSON_CONTAINS_PATH(datos_anteriores, 'one', '$.password_hash') = 1
   OR JSON_CONTAINS_PATH(datos_nuevos, 'one', '$.password_hash') = 1;

SELECT
    id_auditoria,
    accion,
    JSON_EXTRACT(datos_nuevos, '$.password_hash_cambiado')
        AS password_hash_cambiado,
    JSON_CONTAINS_PATH(datos_nuevos, 'one', '$.password_hash')
        AS contiene_hash_real,
    IF(
        JSON_EXTRACT(datos_nuevos, '$.password_hash_cambiado') = 1
        AND JSON_CONTAINS_PATH(datos_nuevos, 'one', '$.password_hash') = 0,
        'PASS',
        'FAIL'
    ) AS resultado
FROM auditoria
WHERE tabla_afectada = 'usuario'
  AND accion = 'cambio_password';

SELECT
    1 AS esperado,
    COUNT(*) AS obtenido,
    IF(COUNT(*) = 1, 'PASS', 'FAIL') AS resultado
FROM auditoria
WHERE tabla_afectada = 'usuario'
  AND accion = 'cambio_password'
  AND JSON_EXTRACT(datos_nuevos, '$.password_hash_cambiado') = 1
  AND JSON_CONTAINS_PATH(datos_nuevos, 'one', '$.password_hash') = 0;

SELECT
    a.id_auditoria,
    a.id_usuario,
    a.origen,
    IF(
        a.id_usuario IS NULL AND a.origen = 'dml_directo',
        'PASS',
        'FAIL'
    ) AS resultado
FROM auditoria AS a
INNER JOIN usuario AS u
        ON u.id_usuario = a.id_registro
WHERE a.tabla_afectada = 'usuario'
  AND a.accion = 'creacion_usuario'
  AND u.nombre_usuario = 'admin_demo';

SELECT origen, COUNT(*) AS cantidad
FROM auditoria
GROUP BY origen
ORDER BY origen;

-- Resultado esperado: 0 filas
SELECT *
FROM auditoria
WHERE origen NOT IN (
    'dml_directo',
    '08_seed_data',
    'sp_registrar_precio',
    'sp_crear_orden_trabajo',
    'sp_actualizar_diagnostico_orden',
    'sp_cambiar_estado_orden',
    'sp_finalizar_orden',
    'sp_generar_factura',
    'sp_registrar_pago',
    'sp_anular_factura'
);

SELECT
    COUNT(*) AS triggers_insert_sobre_auditoria,
    IF(COUNT(*) = 0, 'PASS', 'FAIL') AS resultado
FROM information_schema.triggers
WHERE trigger_schema = 'taller_mecanico'
  AND event_object_table = 'auditoria'
  AND event_manipulation = 'INSERT';

-- ===========================================================================
-- SECCIÓN 6: EXPLAIN DE ÍNDICES
-- ===========================================================================

-- Con pocos datos el optimizador puede preferir un escaneo completo. La columna
-- key de EXPLAIN es informativa y no determina por sí sola PASS o FAIL.

EXPLAIN
SELECT *
FROM historial_precio
WHERE id_servicio = (
    SELECT id_servicio FROM servicio WHERE codigo = 'SER-ACEI'
)
  AND fecha_fin IS NULL
ORDER BY fecha_inicio;

EXPLAIN
SELECT *
FROM historial_precio
WHERE id_repuesto = (
    SELECT id_repuesto FROM repuesto WHERE codigo = 'REP-FILT-ACE'
)
  AND fecha_fin IS NULL
ORDER BY fecha_inicio;

EXPLAIN
SELECT *
FROM orden_trabajo
WHERE id_mecanico = (
    SELECT m.id_mecanico
    FROM mecanico AS m
    INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
    WHERE u.nombre_usuario = 'mecanico_uno'
)
  AND estado IN (
      'ingresada',
      'diagnostico',
      'esperando_repuestos',
      'en_reparacion'
  )
ORDER BY fecha_apertura;

EXPLAIN
SELECT *
FROM orden_trabajo
WHERE id_vehiculo = (
    SELECT id_vehiculo FROM vehiculo WHERE placa = 'PBA-1001'
)
ORDER BY fecha_apertura;

EXPLAIN
SELECT *
FROM orden_trabajo
WHERE estado = 'finalizada'
ORDER BY fecha_apertura;

EXPLAIN
SELECT *
FROM historial_estado_orden
WHERE id_orden_trabajo = (
    SELECT ot.id_orden_trabajo
    FROM orden_trabajo AS ot
    INNER JOIN vehiculo AS v ON v.id_vehiculo = ot.id_vehiculo
    WHERE v.placa = 'PBC-3003'
      AND ot.estado = 'esperando_repuestos'
)
ORDER BY fecha_cambio;

EXPLAIN
SELECT id_repuesto, SUM(cantidad) AS cantidad_total
FROM detalle_orden
WHERE id_orden_trabajo = (
    SELECT ot.id_orden_trabajo
    FROM orden_trabajo AS ot
    INNER JOIN factura AS f ON f.id_orden_trabajo = ot.id_orden_trabajo
    INNER JOIN pago AS p ON p.id_factura = f.id_factura
    INNER JOIN vehiculo AS v ON v.id_vehiculo = ot.id_vehiculo
    WHERE v.placa = 'PBA-1001'
      AND p.estado = 'registrado'
)
  AND id_repuesto IS NOT NULL
GROUP BY id_repuesto;

EXPLAIN
SELECT *
FROM factura
WHERE estado = 'emitida'
ORDER BY fecha_emision;

EXPLAIN
SELECT *
FROM pago
WHERE id_factura = (
    SELECT id_factura
    FROM vw_facturas_estado_cobro
    WHERE estado_cobro = 'pagada'
)
  AND estado = 'registrado';

EXPLAIN
SELECT *
FROM auditoria
WHERE tabla_afectada = 'factura'
  AND id_registro = (
      SELECT id_factura
      FROM vw_facturas_estado_cobro
      WHERE estado_cobro = 'pagada'
  )
ORDER BY fecha_evento;

EXPLAIN
SELECT *
FROM auditoria
WHERE id_usuario = (
    SELECT id_usuario
    FROM usuario
    WHERE nombre_usuario = 'admin_demo'
)
ORDER BY fecha_evento;

-- ===========================================================================
-- SECCIÓN 7: PRUEBA CRUD TRANSACCIONAL SEGURA
-- ===========================================================================

SELECT id_usuario INTO @id_admin_pruebas
FROM usuario
WHERE nombre_usuario = 'admin_demo';

SET @app_id_usuario = @id_admin_pruebas;
SET @app_origen = '09_test_queries';
SET @app_motivo = 'Prueba CRUD transaccional';

START TRANSACTION;

INSERT INTO servicio (
    codigo,
    nombre,
    categoria,
    duracion_estimada_minutos,
    descripcion,
    activo
)
VALUES (
    'TEST-CRUD-09',
    'Servicio temporal CRUD',
    'prueba',
    15,
    'Registro temporal para verificar CREATE',
    1
);

SELECT *
FROM servicio
WHERE codigo = 'TEST-CRUD-09';

UPDATE servicio
SET nombre = 'Servicio temporal CRUD actualizado',
    duracion_estimada_minutos = 20,
    descripcion = 'Registro temporal modificado dentro de la transacción'
WHERE codigo = 'TEST-CRUD-09';

SELECT *
FROM servicio
WHERE codigo = 'TEST-CRUD-09';

DELETE FROM servicio
WHERE codigo = 'TEST-CRUD-09';

SELECT
    COUNT(*) AS registros_dentro_transaccion,
    IF(COUNT(*) = 0, 'PASS', 'FAIL') AS resultado
FROM servicio
WHERE codigo = 'TEST-CRUD-09';

ROLLBACK;

SET @app_id_usuario = NULL;
SET @app_origen = NULL;
SET @app_motivo = NULL;

SELECT
    COUNT(*) AS registros_despues_rollback,
    IF(COUNT(*) = 0, 'PASS', 'FAIL') AS resultado
FROM servicio
WHERE codigo = 'TEST-CRUD-09';

-- ===========================================================================
-- SECCIÓN 8: PRUEBAS AUTOMÁTICAS DE RECHAZO
-- ===========================================================================

DROP TEMPORARY TABLE IF EXISTS tmp_resultados_pruebas_09;
CREATE TEMPORARY TABLE tmp_resultados_pruebas_09 (
    numero_prueba TINYINT UNSIGNED NOT NULL,
    nombre_prueba VARCHAR(150) NOT NULL,
    resultado VARCHAR(10) NOT NULL,
    detalle VARCHAR(255) NOT NULL,
    PRIMARY KEY (numero_prueba)
) ENGINE = MEMORY;

DROP PROCEDURE IF EXISTS sp_ejecutar_pruebas_rechazo_09;

DELIMITER $$

CREATE PROCEDURE sp_ejecutar_pruebas_rechazo_09()
MODIFIES SQL DATA
BEGIN
    DECLARE v_id_admin INT UNSIGNED;
    DECLARE v_id_rol_admin INT UNSIGNED;
    DECLARE v_id_cliente_alterno INT UNSIGNED;
    DECLARE v_id_vehiculo_con_ordenes INT UNSIGNED;
    DECLARE v_id_precio INT UNSIGNED;
    DECLARE v_id_orden_espera INT UNSIGNED;
    DECLARE v_id_detalle_finalizado INT UNSIGNED;
    DECLARE v_id_precio_alterno INT UNSIGNED;
    DECLARE v_id_factura_emitida INT UNSIGNED;
    DECLARE v_id_factura_pagada INT UNSIGNED;
    DECLARE v_total_factura_pagada DECIMAL(12,2);
    DECLARE v_id_pago INT UNSIGNED;
    DECLARE v_id_auditoria BIGINT UNSIGNED;
    DECLARE v_id_cliente_eliminar INT UNSIGNED;

    SELECT id_usuario
      INTO v_id_admin
      FROM usuario
     WHERE nombre_usuario = 'admin_demo';

    SELECT id_rol
      INTO v_id_rol_admin
      FROM rol
     WHERE nombre = 'administrador';

    SELECT id_cliente
      INTO v_id_cliente_alterno
      FROM cliente
     WHERE identificacion = '1791234567001';

    SELECT id_vehiculo
      INTO v_id_vehiculo_con_ordenes
      FROM vehiculo
     WHERE placa = 'PBA-1001';

    SELECT hp.id_historial_precio
      INTO v_id_precio
      FROM historial_precio AS hp
      INNER JOIN servicio AS s ON s.id_servicio = hp.id_servicio
     WHERE s.codigo = 'SER-ACEI'
       AND hp.fecha_fin IS NULL;

    SELECT ot.id_orden_trabajo
      INTO v_id_orden_espera
      FROM orden_trabajo AS ot
      INNER JOIN vehiculo AS v ON v.id_vehiculo = ot.id_vehiculo
     WHERE v.placa = 'PBC-3003'
       AND ot.estado = 'esperando_repuestos';

    SELECT det.id_detalle_orden
      INTO v_id_detalle_finalizado
      FROM detalle_orden AS det
      INNER JOIN orden_trabajo AS ot
              ON ot.id_orden_trabajo = det.id_orden_trabajo
      INNER JOIN factura AS f
              ON f.id_orden_trabajo = ot.id_orden_trabajo
      INNER JOIN pago AS p ON p.id_factura = f.id_factura
     WHERE p.estado = 'registrado'
       AND det.id_servicio IS NOT NULL
     LIMIT 1;

    SELECT hp.id_historial_precio
      INTO v_id_precio_alterno
      FROM historial_precio AS hp
      INNER JOIN servicio AS s ON s.id_servicio = hp.id_servicio
     WHERE s.codigo = 'SER-DIAG'
       AND hp.fecha_fin IS NULL;

    SELECT id_factura
      INTO v_id_factura_emitida
      FROM vw_facturas_estado_cobro
     WHERE estado_cobro = 'pendiente';

    SELECT id_factura, total
      INTO v_id_factura_pagada, v_total_factura_pagada
      FROM vw_facturas_estado_cobro
     WHERE estado_cobro = 'pagada';

    SELECT id_pago
      INTO v_id_pago
      FROM pago
     WHERE id_factura = v_id_factura_pagada
       AND estado = 'registrado';

    SELECT MIN(id_auditoria)
      INTO v_id_auditoria
      FROM auditoria;

    SELECT id_cliente
      INTO v_id_cliente_eliminar
      FROM cliente
     WHERE identificacion = '1756789012';

    SET @app_id_usuario = v_id_admin;
    SET @app_origen = '09_test_queries';
    SET @app_motivo = 'Pruebas automáticas de rechazo';

    START TRANSACTION;

    SAVEPOINT prueba_01;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        INSERT INTO rol (nombre, descripcion, activo)
        VALUES ('superusuario', 'Rol no permitido para la prueba', 1);

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            1,
            'CHECK de nombre de rol',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El CHECK rechazó superusuario', 'El INSERT fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_01;

    SAVEPOINT prueba_02;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        INSERT INTO usuario (
            id_rol, cedula, nombre_usuario, password_hash, nombres,
            apellidos, correo, telefono, activo, fecha_desactivacion
        )
        VALUES (
            v_id_rol_admin,
            '1700000009',
            'admin_demo',
            'DEMO_HASH_PRUEBA_DUPLICADO',
            'Usuario',
            'Duplicado',
            'duplicado.09@example.com',
            '0999999902',
            1,
            NULL
        );

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            2,
            'UNIQUE de nombre_usuario',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'Se rechazó admin_demo duplicado', 'El INSERT fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_02;

    SAVEPOINT prueba_03;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        INSERT INTO mecanico (
            id_usuario,
            especialidad,
            nivel,
            maximo_ordenes_activas,
            disponibilidad,
            activo
        )
        VALUES (
            v_id_admin,
            'Perfil inválido de prueba',
            'junior',
            3,
            'disponible',
            1
        );

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            3,
            'Rol válido para perfil mecanico',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El trigger rechazó al administrador', 'El INSERT fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_03;

    SAVEPOINT prueba_04;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        UPDATE vehiculo
           SET id_cliente = v_id_cliente_alterno
         WHERE id_vehiculo = v_id_vehiculo_con_ordenes;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            4,
            'Propietario inmutable con ordenes',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El trigger protegió el propietario', 'El UPDATE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_04;

    SAVEPOINT prueba_05;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        UPDATE historial_precio
           SET precio_venta = precio_venta + 1.00
         WHERE id_historial_precio = v_id_precio;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            5,
            'Precio histórico inmutable',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El trigger rechazó el nuevo precio', 'El UPDATE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_05;

    SAVEPOINT prueba_06;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        DELETE FROM historial_precio
         WHERE id_historial_precio = v_id_precio;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            6,
            'Eliminación de historial_precio',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El historial quedó protegido', 'El DELETE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_06;

    SAVEPOINT prueba_07;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        UPDATE orden_trabajo
           SET estado = 'finalizada'
         WHERE id_orden_trabajo = v_id_orden_espera;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            7,
            'Finalización directa inválida',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'La transición fue rechazada', 'El UPDATE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_07;

    SAVEPOINT prueba_08;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        UPDATE detalle_orden
           SET id_historial_precio = v_id_precio_alterno
         WHERE id_detalle_orden = v_id_detalle_finalizado;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            8,
            'Precio congelado de detalle',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El precio congelado quedó protegido', 'El UPDATE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_08;

    SAVEPOINT prueba_09;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        DELETE FROM detalle_orden
         WHERE id_detalle_orden = v_id_detalle_finalizado;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            9,
            'Eliminar detalle de orden finalizada',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El detalle finalizado quedó protegido', 'El DELETE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_09;

    SAVEPOINT prueba_10;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        UPDATE factura
           SET total = total + 1.00
         WHERE id_factura = v_id_factura_emitida;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            10,
            'Total de factura inmutable',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El total quedó protegido', 'El UPDATE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_10;

    SAVEPOINT prueba_11;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        DELETE FROM factura
         WHERE id_factura = v_id_factura_emitida;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            11,
            'Eliminación de factura',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'La factura quedó protegida', 'El DELETE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_11;

    SAVEPOINT prueba_12;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        INSERT INTO pago (
            id_factura,
            monto,
            metodo_pago,
            referencia,
            estado,
            fecha_pago,
            id_usuario_registro,
            fecha_anulacion,
            id_usuario_anulacion,
            motivo_anulacion
        )
        VALUES (
            v_id_factura_pagada,
            v_total_factura_pagada,
            'efectivo',
            NULL,
            'registrado',
            CURRENT_TIMESTAMP,
            v_id_admin,
            NULL,
            NULL,
            NULL
        );

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            12,
            'Segundo pago registrado',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El segundo pago fue rechazado', 'El INSERT fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_12;

    SAVEPOINT prueba_13;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        DELETE FROM pago
         WHERE id_pago = v_id_pago;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            13,
            'Eliminación de pago',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El pago quedó protegido', 'El DELETE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_13;

    SAVEPOINT prueba_14;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        UPDATE auditoria
           SET motivo = 'Modificación no permitida'
         WHERE id_auditoria = v_id_auditoria;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            14,
            'Auditoría inmutable',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'La auditoría quedó protegida', 'El UPDATE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_14;

    SAVEPOINT prueba_15;
    BEGIN
        DECLARE v_error TINYINT DEFAULT 0;
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error = 1;

        DELETE FROM cliente
         WHERE id_cliente = v_id_cliente_eliminar;

        INSERT INTO tmp_resultados_pruebas_09
        VALUES (
            15,
            'Eliminación física de cliente',
            IF(v_error = 1, 'PASS', 'FAIL'),
            IF(v_error = 1, 'El cliente quedó protegido', 'El DELETE fue aceptado')
        );
    END;
    ROLLBACK TO SAVEPOINT prueba_15;

    ROLLBACK;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

DELIMITER ;

CALL sp_ejecutar_pruebas_rechazo_09();

SELECT *
FROM tmp_resultados_pruebas_09
ORDER BY numero_prueba;

SELECT resultado, COUNT(*) AS cantidad
FROM tmp_resultados_pruebas_09
GROUP BY resultado
ORDER BY resultado;

DROP PROCEDURE IF EXISTS sp_ejecutar_pruebas_rechazo_09;
DROP TEMPORARY TABLE IF EXISTS tmp_resultados_pruebas_09;

SET @app_id_usuario = NULL;
SET @app_origen = NULL;
SET @app_motivo = NULL;

-- ===========================================================================
-- SECCIÓN 9: VERIFICACIÓN POSTERIOR
-- ===========================================================================

SELECT
    'auditoria' AS comprobacion,
    46 AS esperado,
    COUNT(*) AS obtenido,
    IF(COUNT(*) = 46, 'PASS', 'FAIL') AS resultado
FROM auditoria
UNION ALL
SELECT 'factura', 3, COUNT(*), IF(COUNT(*) = 3, 'PASS', 'FAIL') FROM factura
UNION ALL
SELECT 'pago', 1, COUNT(*), IF(COUNT(*) = 1, 'PASS', 'FAIL') FROM pago
UNION ALL
SELECT
    'orden_trabajo',
    5,
    COUNT(*),
    IF(COUNT(*) = 5, 'PASS', 'FAIL')
FROM orden_trabajo
UNION ALL
SELECT
    'detalle_orden',
    7,
    COUNT(*),
    IF(COUNT(*) = 7, 'PASS', 'FAIL')
FROM detalle_orden
UNION ALL
SELECT 'servicio', 5, COUNT(*), IF(COUNT(*) = 5, 'PASS', 'FAIL') FROM servicio
UNION ALL
SELECT
    'servicio_temporal',
    0,
    COUNT(*),
    IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM servicio
WHERE codigo = 'TEST-CRUD-09';

SELECT
    @app_id_usuario AS app_id_usuario,
    @app_origen AS app_origen,
    @app_motivo AS app_motivo,
    IF(
        @app_id_usuario IS NULL
        AND @app_origen IS NULL
        AND @app_motivo IS NULL,
        'PASS',
        'FAIL'
    ) AS resultado;

SELECT
    COUNT(*) AS procedimiento_auxiliar_existente,
    IF(COUNT(*) = 0, 'PASS', 'FAIL') AS resultado
FROM information_schema.routines
WHERE routine_schema = 'taller_mecanico'
  AND routine_type = 'PROCEDURE'
  AND routine_name = 'sp_ejecutar_pruebas_rechazo_09';
