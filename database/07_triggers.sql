-- Fase 6A: triggers defensivos de validación e inmutabilidad.
-- No incluye auditoría ni lógica operativa que corresponda a procedimientos.

USE taller_mecanico;

DELIMITER $$

-- Exige que un perfil de mecánico corresponda a un usuario con ese rol.
DROP TRIGGER IF EXISTS trg_mecanico_bi_validar_rol$$
CREATE TRIGGER trg_mecanico_bi_validar_rol
BEFORE INSERT ON mecanico
FOR EACH ROW
BEGIN
    DECLARE v_perfil_valido INT DEFAULT 0;

    SELECT COUNT(*)
      INTO v_perfil_valido
      FROM usuario AS u
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = NEW.id_usuario
       AND r.nombre = 'mecanico'
       AND (
           NEW.activo = 0
           OR (u.activo = 1 AND r.activo = 1)
       );

    IF v_perfil_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El perfil debe corresponder a un usuario con rol mecanico activo cuando se habilita';
    END IF;
END$$

-- Conserva la relación válida entre perfil, usuario y rol.
DROP TRIGGER IF EXISTS trg_mecanico_bu_validar_rol$$
CREATE TRIGGER trg_mecanico_bu_validar_rol
BEFORE UPDATE ON mecanico
FOR EACH ROW
BEGIN
    DECLARE v_perfil_valido INT DEFAULT 0;
    DECLARE v_ordenes_asociadas INT DEFAULT 0;

    SELECT COUNT(*)
      INTO v_perfil_valido
      FROM usuario AS u
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = NEW.id_usuario
       AND r.nombre = 'mecanico'
       AND (
           NEW.activo = 0
           OR (u.activo = 1 AND r.activo = 1)
       );

    IF v_perfil_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El perfil debe corresponder a un usuario con rol mecanico activo cuando se habilita';
    END IF;

    IF NOT (NEW.id_usuario <=> OLD.id_usuario) THEN
        SELECT COUNT(*)
          INTO v_ordenes_asociadas
          FROM orden_trabajo AS ot
         WHERE ot.id_mecanico = OLD.id_mecanico;

        IF v_ordenes_asociadas > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se puede cambiar el usuario de un mecanico con ordenes asociadas';
        END IF;
    END IF;
END$$

-- Impide cambiar el propietario cuando el vehículo ya tiene historial.
DROP TRIGGER IF EXISTS trg_vehiculo_bu_bloquear_cambio_propietario$$
CREATE TRIGGER trg_vehiculo_bu_bloquear_cambio_propietario
BEFORE UPDATE ON vehiculo
FOR EACH ROW
BEGIN
    DECLARE v_ordenes_asociadas INT DEFAULT 0;

    IF NOT (NEW.id_cliente <=> OLD.id_cliente) THEN
        SELECT COUNT(*)
          INTO v_ordenes_asociadas
          FROM orden_trabajo AS ot
         WHERE ot.id_vehiculo = OLD.id_vehiculo;

        IF v_ordenes_asociadas > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se puede cambiar el propietario de un vehiculo con ordenes';
        END IF;
    END IF;
END$$

-- Valida estado, precio congelado y stock preventivo al insertar un detalle.
DROP TRIGGER IF EXISTS trg_detalle_orden_bi_validar_integridad$$
CREATE TRIGGER trg_detalle_orden_bi_validar_integridad
BEFORE INSERT ON detalle_orden
FOR EACH ROW
BEGIN
    DECLARE v_estado_orden VARCHAR(25) DEFAULT NULL;
    DECLARE v_precio_existe INT DEFAULT 0;
    DECLARE v_id_servicio_precio INT UNSIGNED DEFAULT NULL;
    DECLARE v_id_repuesto_precio INT UNSIGNED DEFAULT NULL;
    DECLARE v_precio_venta DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_fecha_fin DATETIME DEFAULT NULL;
    DECLARE v_servicio_existe INT DEFAULT 0;
    DECLARE v_servicio_activo TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_repuesto_existe INT DEFAULT 0;
    DECLARE v_repuesto_activo TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_stock_actual DECIMAL(12,2) DEFAULT NULL;

    SELECT MAX(ot.estado)
      INTO v_estado_orden
      FROM orden_trabajo AS ot
     WHERE ot.id_orden_trabajo = NEW.id_orden_trabajo;

    IF v_estado_orden IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden de trabajo no existe';
    END IF;

    IF v_estado_orden NOT IN (
        'diagnostico',
        'esperando_repuestos',
        'en_reparacion'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden no admite detalles en su estado actual';
    END IF;

    SELECT COUNT(*),
           MAX(hp.id_servicio),
           MAX(hp.id_repuesto),
           MAX(hp.precio_venta),
           MAX(hp.fecha_fin)
      INTO v_precio_existe,
           v_id_servicio_precio,
           v_id_repuesto_precio,
           v_precio_venta,
           v_fecha_fin
      FROM historial_precio AS hp
     WHERE hp.id_historial_precio = NEW.id_historial_precio;

    IF v_precio_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio historico no existe';
    END IF;

    IF v_fecha_fin IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio historico ya no esta vigente';
    END IF;

    IF NEW.id_servicio IS NOT NULL
       AND (
           NOT (v_id_servicio_precio <=> NEW.id_servicio)
           OR v_id_repuesto_precio IS NOT NULL
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio historico no corresponde al servicio';
    END IF;

    IF NEW.id_repuesto IS NOT NULL
       AND (
           NOT (v_id_repuesto_precio <=> NEW.id_repuesto)
           OR v_id_servicio_precio IS NOT NULL
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio historico no corresponde al repuesto';
    END IF;

    IF NOT (NEW.precio_unitario <=> v_precio_venta) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio unitario debe coincidir con el precio historico';
    END IF;

    IF NEW.id_servicio IS NOT NULL THEN
        SELECT COUNT(*), MAX(s.activo)
          INTO v_servicio_existe, v_servicio_activo
          FROM servicio AS s
         WHERE s.id_servicio = NEW.id_servicio;

        IF v_servicio_existe = 0 OR v_servicio_activo <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El servicio no existe o esta inactivo';
        END IF;
    END IF;

    IF NEW.id_repuesto IS NOT NULL THEN
        SELECT COUNT(*), MAX(r.activo), MAX(r.stock_actual)
          INTO v_repuesto_existe, v_repuesto_activo, v_stock_actual
          FROM repuesto AS r
         WHERE r.id_repuesto = NEW.id_repuesto;

        IF v_repuesto_existe = 0 OR v_repuesto_activo <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El repuesto no existe o esta inactivo';
        END IF;

        IF v_stock_actual < NEW.cantidad THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El stock actual es insuficiente para el detalle';
        END IF;
    END IF;
END$$

-- Revalida la integridad de un detalle editable sin exigir precio aún vigente.
DROP TRIGGER IF EXISTS trg_detalle_orden_bu_validar_integridad$$
CREATE TRIGGER trg_detalle_orden_bu_validar_integridad
BEFORE UPDATE ON detalle_orden
FOR EACH ROW
BEGIN
    DECLARE v_estado_orden VARCHAR(25) DEFAULT NULL;
    DECLARE v_precio_existe INT DEFAULT 0;
    DECLARE v_id_servicio_precio INT UNSIGNED DEFAULT NULL;
    DECLARE v_id_repuesto_precio INT UNSIGNED DEFAULT NULL;
    DECLARE v_precio_venta DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_repuesto_existe INT DEFAULT 0;
    DECLARE v_stock_actual DECIMAL(12,2) DEFAULT NULL;

    IF NOT (NEW.id_orden_trabajo <=> OLD.id_orden_trabajo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede mover un detalle a otra orden';
    END IF;

    IF NOT (NEW.id_servicio <=> OLD.id_servicio)
       OR NOT (NEW.id_repuesto <=> OLD.id_repuesto)
       OR NOT (NEW.id_historial_precio <=> OLD.id_historial_precio)
       OR NOT (NEW.descripcion_concepto <=> OLD.descripcion_concepto)
       OR NOT (NEW.precio_unitario <=> OLD.precio_unitario)
       OR NOT (NEW.fecha_creacion <=> OLD.fecha_creacion) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El concepto y el precio congelado del detalle son inmutables; elimine y vuelva a agregar el detalle';
    END IF;

    SELECT MAX(ot.estado)
      INTO v_estado_orden
      FROM orden_trabajo AS ot
     WHERE ot.id_orden_trabajo = NEW.id_orden_trabajo;

    IF v_estado_orden IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden de trabajo no existe';
    END IF;

    IF v_estado_orden NOT IN (
        'diagnostico',
        'esperando_repuestos',
        'en_reparacion'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden no admite modificar detalles en su estado actual';
    END IF;

    SELECT COUNT(*),
           MAX(hp.id_servicio),
           MAX(hp.id_repuesto),
           MAX(hp.precio_venta)
      INTO v_precio_existe,
           v_id_servicio_precio,
           v_id_repuesto_precio,
           v_precio_venta
      FROM historial_precio AS hp
     WHERE hp.id_historial_precio = NEW.id_historial_precio;

    IF v_precio_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio historico no existe';
    END IF;

    IF NEW.id_servicio IS NOT NULL
       AND (
           NOT (v_id_servicio_precio <=> NEW.id_servicio)
           OR v_id_repuesto_precio IS NOT NULL
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio historico no corresponde al servicio';
    END IF;

    IF NEW.id_repuesto IS NOT NULL
       AND (
           NOT (v_id_repuesto_precio <=> NEW.id_repuesto)
           OR v_id_servicio_precio IS NOT NULL
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio historico no corresponde al repuesto';
    END IF;

    IF NOT (NEW.precio_unitario <=> v_precio_venta) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio unitario debe coincidir con el precio historico';
    END IF;

    IF NEW.id_repuesto IS NOT NULL THEN
        SELECT COUNT(*), MAX(r.stock_actual)
          INTO v_repuesto_existe, v_stock_actual
          FROM repuesto AS r
         WHERE r.id_repuesto = NEW.id_repuesto;

        IF v_repuesto_existe = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El repuesto no existe';
        END IF;

        IF v_stock_actual < NEW.cantidad THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El stock actual es insuficiente para el detalle';
        END IF;
    END IF;
END$$

-- Solo permite eliminar detalles de órdenes todavía editables.
DROP TRIGGER IF EXISTS trg_detalle_orden_bd_validar_eliminacion$$
CREATE TRIGGER trg_detalle_orden_bd_validar_eliminacion
BEFORE DELETE ON detalle_orden
FOR EACH ROW
BEGIN
    DECLARE v_estado_orden VARCHAR(25) DEFAULT NULL;

    SELECT MAX(ot.estado)
      INTO v_estado_orden
      FROM orden_trabajo AS ot
     WHERE ot.id_orden_trabajo = OLD.id_orden_trabajo;

    IF v_estado_orden IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden de trabajo no existe';
    END IF;

    IF v_estado_orden NOT IN (
        'diagnostico',
        'esperando_repuestos',
        'en_reparacion'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede eliminar el detalle en el estado actual de la orden';
    END IF;
END$$

-- Permite cerrar una vigencia, pero impide reescribir el precio histórico.
DROP TRIGGER IF EXISTS trg_historial_precio_bu_proteger_historial$$
CREATE TRIGGER trg_historial_precio_bu_proteger_historial
BEFORE UPDATE ON historial_precio
FOR EACH ROW
BEGIN
    IF NOT (NEW.id_servicio <=> OLD.id_servicio)
       OR NOT (NEW.id_repuesto <=> OLD.id_repuesto)
       OR NOT (NEW.costo_base <=> OLD.costo_base)
       OR NOT (NEW.precio_venta <=> OLD.precio_venta)
       OR NOT (NEW.fecha_inicio <=> OLD.fecha_inicio)
       OR NOT (NEW.id_usuario_creador <=> OLD.id_usuario_creador)
       OR NOT (NEW.fecha_creacion <=> OLD.fecha_creacion) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede reescribir la informacion de un precio historico';
    END IF;

    IF NOT (NEW.fecha_fin <=> OLD.fecha_fin)
       AND NOT (
           OLD.fecha_fin IS NULL
           AND NEW.fecha_fin IS NOT NULL
           AND NEW.fecha_fin > OLD.fecha_inicio
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La unica transicion permitida es cerrar un precio vigente';
    END IF;
END$$

-- Conserva siempre los registros del historial de precios.
DROP TRIGGER IF EXISTS trg_historial_precio_bd_proteger_historial$$
CREATE TRIGGER trg_historial_precio_bd_proteger_historial
BEFORE DELETE ON historial_precio
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El historial de precios debe conservarse; use el reinicio completo de la base';
END$$

-- Defiende la matriz de estados y la inmutabilidad de las órdenes terminales.
DROP TRIGGER IF EXISTS trg_orden_trabajo_bu_validar_flujo$$
CREATE TRIGGER trg_orden_trabajo_bu_validar_flujo
BEFORE UPDATE ON orden_trabajo
FOR EACH ROW
BEGIN
    DECLARE v_mecanico_valido INT DEFAULT 0;
    DECLARE v_cantidad_detalles INT DEFAULT 0;
    DECLARE v_transicion_valida TINYINT UNSIGNED DEFAULT 0;

    IF OLD.estado IN ('finalizada', 'cancelada') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede modificar una orden en estado terminal';
    END IF;

    IF NOT (NEW.id_vehiculo <=> OLD.id_vehiculo)
       OR NOT (NEW.id_usuario_apertura <=> OLD.id_usuario_apertura)
       OR NOT (NEW.fecha_apertura <=> OLD.fecha_apertura) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar el vehiculo, usuario o fecha de apertura';
    END IF;

    IF NOT (NEW.id_mecanico <=> OLD.id_mecanico) THEN
        IF OLD.estado NOT IN ('ingresada', 'diagnostico') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El mecanico solo puede cambiarse al ingresar o diagnosticar';
        END IF;

        SELECT COUNT(*)
          INTO v_mecanico_valido
          FROM mecanico AS m
          INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
          INNER JOIN rol AS r ON r.id_rol = u.id_rol
         WHERE m.id_mecanico = NEW.id_mecanico
           AND m.activo = 1
           AND u.activo = 1
           AND r.activo = 1
           AND r.nombre = 'mecanico';

        IF v_mecanico_valido = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El nuevo mecanico no tiene un perfil y rol activos validos';
        END IF;
    END IF;

    IF NOT (NEW.estado <=> OLD.estado) THEN
        SET v_transicion_valida = CASE
            WHEN OLD.estado = 'ingresada'
                 AND NEW.estado IN ('diagnostico', 'cancelada') THEN 1
            WHEN OLD.estado = 'diagnostico'
                 AND NEW.estado IN (
                     'esperando_repuestos',
                     'en_reparacion',
                     'cancelada'
                 ) THEN 1
            WHEN OLD.estado = 'esperando_repuestos'
                 AND NEW.estado IN ('en_reparacion', 'cancelada') THEN 1
            WHEN OLD.estado = 'en_reparacion'
                 AND NEW.estado IN (
                     'esperando_repuestos',
                     'cancelada',
                     'finalizada'
                 ) THEN 1
            ELSE 0
        END;

        IF v_transicion_valida = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La transicion de estado no esta permitida';
        END IF;
    END IF;

    IF NEW.estado = 'finalizada' THEN
        IF OLD.estado <> 'en_reparacion'
           OR NEW.diagnostico IS NULL
           OR TRIM(NEW.diagnostico) = ''
           OR NEW.inventario_descontado <> 1
           OR NEW.fecha_finalizacion IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La finalizacion no cumple las condiciones operativas';
        END IF;

        SELECT COUNT(*)
          INTO v_cantidad_detalles
          FROM detalle_orden AS det
         WHERE det.id_orden_trabajo = OLD.id_orden_trabajo;

        IF v_cantidad_detalles = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La orden debe tener al menos un detalle para finalizar';
        END IF;
    ELSEIF NEW.inventario_descontado <> 0
           OR NEW.fecha_finalizacion IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Una orden no finalizada no puede tener cierre ni inventario descontado';
    END IF;
END$$

-- Hace inmutable la factura salvo por su anulación controlada.
DROP TRIGGER IF EXISTS trg_factura_bu_proteger_inmutabilidad$$
CREATE TRIGGER trg_factura_bu_proteger_inmutabilidad
BEFORE UPDATE ON factura
FOR EACH ROW
BEGIN
    DECLARE v_pagos_registrados INT DEFAULT 0;

    IF NOT (NEW.id_orden_trabajo <=> OLD.id_orden_trabajo)
       OR NOT (NEW.fecha_emision <=> OLD.fecha_emision)
       OR NOT (NEW.subtotal <=> OLD.subtotal)
       OR NOT (NEW.porcentaje_iva <=> OLD.porcentaje_iva)
       OR NOT (NEW.valor_iva <=> OLD.valor_iva)
       OR NOT (NEW.total <=> OLD.total)
       OR NOT (NEW.id_usuario_emision <=> OLD.id_usuario_emision)
       OR NOT (NEW.identificacion_cliente <=> OLD.identificacion_cliente)
       OR NOT (NEW.nombre_cliente <=> OLD.nombre_cliente)
       OR NOT (NEW.direccion_cliente <=> OLD.direccion_cliente)
       OR NOT (NEW.placa_vehiculo <=> OLD.placa_vehiculo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los datos emitidos de la factura son inmutables';
    END IF;

    IF OLD.estado = 'anulada' THEN
        IF NOT (NEW.estado <=> OLD.estado)
           OR NOT (NEW.fecha_anulacion <=> OLD.fecha_anulacion)
           OR NOT (NEW.id_usuario_anulacion <=> OLD.id_usuario_anulacion)
           OR NOT (NEW.motivo_anulacion <=> OLD.motivo_anulacion) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Una factura anulada no puede modificarse';
        END IF;
    ELSEIF NEW.estado = 'anulada' THEN
        IF NEW.fecha_anulacion IS NULL
           OR NEW.id_usuario_anulacion IS NULL
           OR NEW.motivo_anulacion IS NULL
           OR TRIM(NEW.motivo_anulacion) = '' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La anulacion de factura requiere fecha, usuario y motivo';
        END IF;

        SELECT COUNT(*)
          INTO v_pagos_registrados
          FROM pago AS p
         WHERE p.id_factura = OLD.id_factura
           AND p.estado = 'registrado';

        IF v_pagos_registrados > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se puede anular una factura con un pago registrado';
        END IF;
    ELSEIF NEW.estado = 'emitida' THEN
        IF NEW.fecha_anulacion IS NOT NULL
           OR NEW.id_usuario_anulacion IS NOT NULL
           OR NEW.motivo_anulacion IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Una factura emitida no puede tener datos de anulacion';
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La transicion de estado de factura no esta permitida';
    END IF;
END$$

-- Hace inmutable el pago salvo por su anulación controlada.
DROP TRIGGER IF EXISTS trg_pago_bu_proteger_inmutabilidad$$
CREATE TRIGGER trg_pago_bu_proteger_inmutabilidad
BEFORE UPDATE ON pago
FOR EACH ROW
BEGIN
    DECLARE v_factura_emitida INT DEFAULT 0;

    IF NOT (NEW.id_factura <=> OLD.id_factura)
       OR NOT (NEW.monto <=> OLD.monto)
       OR NOT (NEW.metodo_pago <=> OLD.metodo_pago)
       OR NOT (NEW.referencia <=> OLD.referencia)
       OR NOT (NEW.fecha_pago <=> OLD.fecha_pago)
       OR NOT (NEW.id_usuario_registro <=> OLD.id_usuario_registro) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los datos registrados del pago son inmutables';
    END IF;

    IF OLD.estado = 'anulado' THEN
        IF NOT (NEW.estado <=> OLD.estado)
           OR NOT (NEW.fecha_anulacion <=> OLD.fecha_anulacion)
           OR NOT (NEW.id_usuario_anulacion <=> OLD.id_usuario_anulacion)
           OR NOT (NEW.motivo_anulacion <=> OLD.motivo_anulacion) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Un pago anulado no puede modificarse';
        END IF;
    ELSEIF NEW.estado = 'anulado' THEN
        IF NEW.fecha_anulacion IS NULL
           OR NEW.id_usuario_anulacion IS NULL
           OR NEW.motivo_anulacion IS NULL
           OR TRIM(NEW.motivo_anulacion) = '' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La anulacion del pago requiere fecha, usuario y motivo';
        END IF;

        SELECT COUNT(*)
          INTO v_factura_emitida
          FROM factura AS f
         WHERE f.id_factura = OLD.id_factura
           AND f.estado = 'emitida';

        IF v_factura_emitida = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El pago solo puede anularse si la factura sigue emitida';
        END IF;
    ELSEIF NEW.estado = 'registrado' THEN
        IF NEW.fecha_anulacion IS NOT NULL
           OR NEW.id_usuario_anulacion IS NOT NULL
           OR NEW.motivo_anulacion IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Un pago registrado no puede tener datos de anulacion';
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La transicion de estado del pago no esta permitida';
    END IF;
END$$

-- Valida que una factura nueva refleje una orden finalizada y sus importes.
DROP TRIGGER IF EXISTS trg_factura_bi_validar_integridad$$
CREATE TRIGGER trg_factura_bi_validar_integridad
BEFORE INSERT ON factura
FOR EACH ROW
BEGIN
    DECLARE v_orden_existe INT DEFAULT 0;
    DECLARE v_estado_orden VARCHAR(25) DEFAULT NULL;
    DECLARE v_inventario_descontado TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_fecha_finalizacion DATETIME DEFAULT NULL;
    DECLARE v_identificacion_cliente VARCHAR(13) DEFAULT NULL;
    DECLARE v_nombre_cliente VARCHAR(200) DEFAULT NULL;
    DECLARE v_direccion_cliente VARCHAR(255) DEFAULT NULL;
    DECLARE v_placa_vehiculo VARCHAR(10) DEFAULT NULL;
    DECLARE v_cantidad_detalles INT DEFAULT 0;
    DECLARE v_subtotal_orden DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_facturas_existentes INT DEFAULT 0;
    DECLARE v_usuario_valido INT DEFAULT 0;

    SELECT COUNT(*),
           MAX(ot.estado),
           MAX(ot.inventario_descontado),
           MAX(ot.fecha_finalizacion),
           MAX(c.identificacion),
           MAX(
               CASE
                   WHEN c.tipo_cliente = 'persona'
                       THEN CONCAT_WS(
                           ' ',
                           NULLIF(TRIM(c.nombres), ''),
                           NULLIF(TRIM(c.apellidos), '')
                       )
                   WHEN c.tipo_cliente = 'empresa'
                       THEN c.razon_social
                   ELSE NULL
               END
           ),
           MAX(c.direccion),
           MAX(v.placa)
      INTO v_orden_existe,
           v_estado_orden,
           v_inventario_descontado,
           v_fecha_finalizacion,
           v_identificacion_cliente,
           v_nombre_cliente,
           v_direccion_cliente,
           v_placa_vehiculo
      FROM orden_trabajo AS ot
      INNER JOIN vehiculo AS v ON v.id_vehiculo = ot.id_vehiculo
      INNER JOIN cliente AS c ON c.id_cliente = v.id_cliente
     WHERE ot.id_orden_trabajo = NEW.id_orden_trabajo;

    IF v_orden_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden, el vehiculo o el cliente asociado no existe';
    END IF;

    IF v_estado_orden <> 'finalizada'
       OR v_inventario_descontado <> 1
       OR v_fecha_finalizacion IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se puede facturar una orden finalizada con inventario descontado';
    END IF;

    SELECT COUNT(*), SUM(det.subtotal)
      INTO v_cantidad_detalles, v_subtotal_orden
      FROM detalle_orden AS det
     WHERE det.id_orden_trabajo = NEW.id_orden_trabajo;

    IF v_cantidad_detalles = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden debe contener al menos un detalle';
    END IF;

    SELECT COUNT(*)
      INTO v_facturas_existentes
      FROM factura AS f
     WHERE f.id_orden_trabajo = NEW.id_orden_trabajo;

    IF v_facturas_existentes > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden ya tiene una factura';
    END IF;

    IF NEW.estado <> 'emitida'
       OR NEW.fecha_anulacion IS NOT NULL
       OR NEW.id_usuario_anulacion IS NOT NULL
       OR NEW.motivo_anulacion IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Una factura nueva debe estar emitida y sin datos de anulacion';
    END IF;

    SELECT COUNT(*)
      INTO v_usuario_valido
      FROM usuario AS u
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = NEW.id_usuario_emision
       AND u.activo = 1
       AND r.activo = 1
       AND r.nombre IN ('administrador', 'asesor');

    IF v_usuario_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario de emision no esta activo o no tiene un rol permitido';
    END IF;

    SET v_identificacion_cliente = NULLIF(TRIM(v_identificacion_cliente), '');
    SET v_nombre_cliente = NULLIF(TRIM(v_nombre_cliente), '');
    SET v_placa_vehiculo = NULLIF(TRIM(v_placa_vehiculo), '');

    IF NOT (NEW.identificacion_cliente <=> v_identificacion_cliente)
       OR NOT (NEW.nombre_cliente <=> v_nombre_cliente)
       OR NOT (NEW.direccion_cliente <=> v_direccion_cliente)
       OR NOT (NEW.placa_vehiculo <=> v_placa_vehiculo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La instantanea de cliente y vehiculo no coincide con la orden';
    END IF;

    IF NOT (NEW.subtotal <=> v_subtotal_orden)
       OR NEW.porcentaje_iva <> 15.00
       OR NEW.valor_iva <> ROUND(NEW.subtotal * 15.00 / 100, 2)
       OR NEW.total <> NEW.subtotal + NEW.valor_iva THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los importes de la factura no coinciden con los detalles de la orden';
    END IF;

    IF NEW.fecha_emision < v_fecha_finalizacion THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La fecha de emision no puede ser anterior a la finalizacion';
    END IF;
END$$

-- Exige que cada detalle facturado sea una copia exacta de su detalle de orden.
DROP TRIGGER IF EXISTS trg_detalle_factura_bi_validar_integridad$$
CREATE TRIGGER trg_detalle_factura_bi_validar_integridad
BEFORE INSERT ON detalle_factura
FOR EACH ROW
BEGIN
    DECLARE v_factura_existe INT DEFAULT 0;
    DECLARE v_estado_factura VARCHAR(10) DEFAULT NULL;
    DECLARE v_id_orden_factura INT UNSIGNED DEFAULT NULL;
    DECLARE v_detalle_existe INT DEFAULT 0;
    DECLARE v_id_orden_detalle INT UNSIGNED DEFAULT NULL;
    DECLARE v_tipo_concepto VARCHAR(10) DEFAULT NULL;
    DECLARE v_codigo_concepto VARCHAR(40) DEFAULT NULL;
    DECLARE v_descripcion_concepto VARCHAR(255) DEFAULT NULL;
    DECLARE v_cantidad DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_precio_unitario DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_subtotal DECIMAL(12,2) DEFAULT NULL;

    SELECT COUNT(*), MAX(f.estado), MAX(f.id_orden_trabajo)
      INTO v_factura_existe, v_estado_factura, v_id_orden_factura
      FROM factura AS f
     WHERE f.id_factura = NEW.id_factura;

    IF v_factura_existe = 0 OR v_estado_factura <> 'emitida' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La factura no existe o no esta emitida';
    END IF;

    SELECT COUNT(*),
           MAX(det.id_orden_trabajo),
           MAX(
               CASE
                   WHEN det.id_servicio IS NOT NULL THEN 'servicio'
                   ELSE 'repuesto'
               END
           ),
           MAX(
               CASE
                   WHEN det.id_servicio IS NOT NULL THEN s.codigo
                   ELSE r.codigo
               END
           ),
           MAX(det.descripcion_concepto),
           MAX(det.cantidad),
           MAX(det.precio_unitario),
           MAX(det.subtotal)
      INTO v_detalle_existe,
           v_id_orden_detalle,
           v_tipo_concepto,
           v_codigo_concepto,
           v_descripcion_concepto,
           v_cantidad,
           v_precio_unitario,
           v_subtotal
      FROM detalle_orden AS det
      LEFT JOIN servicio AS s ON s.id_servicio = det.id_servicio
      LEFT JOIN repuesto AS r ON r.id_repuesto = det.id_repuesto
     WHERE det.id_detalle_orden = NEW.id_detalle_orden;

    IF v_detalle_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El detalle de orden no existe';
    END IF;

    IF NOT (v_id_orden_detalle <=> v_id_orden_factura) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El detalle no pertenece a la orden de la factura';
    END IF;

    IF NOT (NEW.tipo_concepto <=> v_tipo_concepto)
       OR NOT (NEW.codigo_concepto <=> v_codigo_concepto)
       OR NOT (NEW.descripcion_concepto <=> v_descripcion_concepto)
       OR NOT (NEW.cantidad <=> v_cantidad)
       OR NOT (NEW.precio_unitario <=> v_precio_unitario)
       OR NOT (NEW.subtotal <=> v_subtotal) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El detalle de factura no coincide con el detalle de orden';
    END IF;
END$$

-- Valida y serializa el registro directo de un pago total.
DROP TRIGGER IF EXISTS trg_pago_bi_validar_integridad$$
CREATE TRIGGER trg_pago_bi_validar_integridad
BEFORE INSERT ON pago
FOR EACH ROW
BEGIN
    DECLARE v_usuario_valido INT DEFAULT 0;
    DECLARE v_estado_factura VARCHAR(10) DEFAULT NULL;
    DECLARE v_total_factura DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_fecha_emision DATETIME DEFAULT NULL;
    DECLARE v_pagos_registrados INT DEFAULT 0;

    SELECT COUNT(*)
      INTO v_usuario_valido
      FROM usuario AS u
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = NEW.id_usuario_registro
       AND u.activo = 1
       AND r.activo = 1
       AND r.nombre IN ('administrador', 'asesor');

    IF v_usuario_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario de registro no esta activo o no tiene un rol permitido';
    END IF;

    -- La factura se bloquea antes de consultar pagos para serializar altas.
    SELECT f.estado, f.total, f.fecha_emision
      INTO v_estado_factura, v_total_factura, v_fecha_emision
      FROM factura AS f
     WHERE f.id_factura = NEW.id_factura
     FOR UPDATE;

    IF v_estado_factura IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La factura no existe';
    END IF;

    IF v_estado_factura <> 'emitida' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se puede pagar una factura emitida';
    END IF;

    IF NOT (NEW.monto <=> v_total_factura) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pago debe ser exactamente igual al total de la factura';
    END IF;

    IF NEW.fecha_pago < v_fecha_emision THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La fecha de pago no puede ser anterior a la emision';
    END IF;

    SELECT COUNT(*)
      INTO v_pagos_registrados
      FROM pago AS p
     WHERE p.id_factura = NEW.id_factura
       AND p.estado = 'registrado';

    IF v_pagos_registrados > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La factura ya tiene un pago registrado';
    END IF;

    IF NEW.estado <> 'registrado'
       OR NEW.fecha_anulacion IS NOT NULL
       OR NEW.id_usuario_anulacion IS NOT NULL
       OR NEW.motivo_anulacion IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un pago nuevo debe estar registrado y sin datos de anulacion';
    END IF;

    IF NEW.metodo_pago IN ('tarjeta', 'transferencia')
       AND (
           NEW.referencia IS NULL
           OR TRIM(NEW.referencia) = ''
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La referencia es obligatoria para tarjeta o transferencia';
    END IF;

    IF NEW.metodo_pago = 'efectivo'
       AND NEW.referencia IS NOT NULL
       AND TRIM(NEW.referencia) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La referencia informada para efectivo no puede estar vacia';
    END IF;
END$$

-- Los clientes se conservan mediante desactivación lógica.
DROP TRIGGER IF EXISTS trg_cliente_bd_proteger_eliminacion$$
CREATE TRIGGER trg_cliente_bd_proteger_eliminacion
BEFORE DELETE ON cliente
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Los clientes se desactivan de forma logica y no pueden eliminarse fisicamente';
END$$

-- Los vehículos se conservan mediante desactivación lógica.
DROP TRIGGER IF EXISTS trg_vehiculo_bd_proteger_eliminacion$$
CREATE TRIGGER trg_vehiculo_bd_proteger_eliminacion
BEFORE DELETE ON vehiculo
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Los vehiculos se desactivan de forma logica y no pueden eliminarse fisicamente';
END$$

-- Conserva toda orden de trabajo como historial operativo.
DROP TRIGGER IF EXISTS trg_orden_trabajo_bd_proteger_eliminacion$$
CREATE TRIGGER trg_orden_trabajo_bd_proteger_eliminacion
BEFORE DELETE ON orden_trabajo
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Las ordenes de trabajo no pueden eliminarse fisicamente';
END$$

-- El historial de estados no admite correcciones posteriores.
DROP TRIGGER IF EXISTS trg_historial_estado_orden_bu_proteger_inmutabilidad$$
CREATE TRIGGER trg_historial_estado_orden_bu_proteger_inmutabilidad
BEFORE UPDATE ON historial_estado_orden
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El historial de estados es inmutable';
END$$

-- El historial de estados no admite eliminaciones físicas.
DROP TRIGGER IF EXISTS trg_historial_estado_orden_bd_proteger_inmutabilidad$$
CREATE TRIGGER trg_historial_estado_orden_bd_proteger_inmutabilidad
BEFORE DELETE ON historial_estado_orden
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El historial de estados no puede eliminarse';
END$$

-- Las facturas se conservan y se corrigen mediante anulación.
DROP TRIGGER IF EXISTS trg_factura_bd_proteger_eliminacion$$
CREATE TRIGGER trg_factura_bd_proteger_eliminacion
BEFORE DELETE ON factura
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Las facturas deben conservarse y solo pueden anularse';
END$$

-- Ningún dato de un detalle facturado puede modificarse.
DROP TRIGGER IF EXISTS trg_detalle_factura_bu_proteger_inmutabilidad$$
CREATE TRIGGER trg_detalle_factura_bu_proteger_inmutabilidad
BEFORE UPDATE ON detalle_factura
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Los detalles de una factura emitida son inmutables';
END$$

-- Los detalles facturados forman parte permanente de la factura.
DROP TRIGGER IF EXISTS trg_detalle_factura_bd_proteger_eliminacion$$
CREATE TRIGGER trg_detalle_factura_bd_proteger_eliminacion
BEFORE DELETE ON detalle_factura
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Los detalles de factura no pueden eliminarse';
END$$

-- Los pagos se conservan y se corrigen mediante anulación.
DROP TRIGGER IF EXISTS trg_pago_bd_proteger_eliminacion$$
CREATE TRIGGER trg_pago_bd_proteger_eliminacion
BEFORE DELETE ON pago
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Los pagos deben conservarse y solo pueden anularse';
END$$

-- Los registros de auditoría son de solo escritura.
DROP TRIGGER IF EXISTS trg_auditoria_bu_proteger_inmutabilidad$$
CREATE TRIGGER trg_auditoria_bu_proteger_inmutabilidad
BEFORE UPDATE ON auditoria
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Los registros de auditoria son inmutables';
END$$

-- Los registros de auditoría nunca se eliminan físicamente.
DROP TRIGGER IF EXISTS trg_auditoria_bd_proteger_inmutabilidad$$
CREATE TRIGGER trg_auditoria_bd_proteger_inmutabilidad
BEFORE DELETE ON auditoria
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Los registros de auditoria no pueden eliminarse';
END$$

-- Audita la creación de una nueva vigencia de precio.
DROP TRIGGER IF EXISTS trg_historial_precio_ai_auditar$$
CREATE TRIGGER trg_historial_precio_ai_auditar
AFTER INSERT ON historial_precio
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (
        id_usuario, tabla_afectada, id_registro, accion, motivo,
        datos_anteriores, datos_nuevos, origen, direccion_ip
    )
    VALUES (
        @app_id_usuario,
        'historial_precio',
        NEW.id_historial_precio,
        'nuevo_precio',
        NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
        NULL,
        JSON_OBJECT(
            'id_historial_precio', NEW.id_historial_precio,
            'id_servicio', NEW.id_servicio,
            'id_repuesto', NEW.id_repuesto,
            'costo_base', NEW.costo_base,
            'precio_venta', NEW.precio_venta,
            'fecha_inicio', NEW.fecha_inicio,
            'fecha_fin', NEW.fecha_fin,
            'id_usuario_creador', NEW.id_usuario_creador
        ),
        COALESCE(
            NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
            'dml_directo'
        ),
        NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
    );
END$$

-- Audita el cierre de una vigencia de precio.
DROP TRIGGER IF EXISTS trg_historial_precio_au_auditar$$
CREATE TRIGGER trg_historial_precio_au_auditar
AFTER UPDATE ON historial_precio
FOR EACH ROW
BEGIN
    IF NOT (NEW.fecha_fin <=> OLD.fecha_fin) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'historial_precio',
            NEW.id_historial_precio,
            'cierre_precio',
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'fecha_fin', OLD.fecha_fin,
                'precio_venta', OLD.precio_venta,
                'costo_base', OLD.costo_base
            ),
            JSON_OBJECT(
                'fecha_fin', NEW.fecha_fin,
                'precio_venta', NEW.precio_venta,
                'costo_base', NEW.costo_base
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita cambios operativos relevantes de una orden.
DROP TRIGGER IF EXISTS trg_orden_trabajo_au_auditar$$
CREATE TRIGGER trg_orden_trabajo_au_auditar
AFTER UPDATE ON orden_trabajo
FOR EACH ROW
BEGIN
    IF NOT (NEW.id_mecanico <=> OLD.id_mecanico)
       OR NOT (NEW.estado <=> OLD.estado)
       OR NOT (NEW.diagnostico <=> OLD.diagnostico)
       OR NOT (NEW.observacion <=> OLD.observacion)
       OR NOT (NEW.kilometraje_ingreso <=> OLD.kilometraje_ingreso)
       OR NOT (NEW.inventario_descontado <=> OLD.inventario_descontado)
       OR NOT (NEW.fecha_finalizacion <=> OLD.fecha_finalizacion) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'orden_trabajo',
            NEW.id_orden_trabajo,
            CASE
                WHEN NOT (NEW.estado <=> OLD.estado)
                    THEN 'cambio_estado'
                WHEN NOT (NEW.id_mecanico <=> OLD.id_mecanico)
                    THEN 'reasignacion_mecanico'
                ELSE 'actualizacion_orden'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'id_mecanico', OLD.id_mecanico,
                'estado', OLD.estado,
                'diagnostico', OLD.diagnostico,
                'observacion', OLD.observacion,
                'kilometraje_ingreso', OLD.kilometraje_ingreso,
                'inventario_descontado', OLD.inventario_descontado,
                'fecha_finalizacion', OLD.fecha_finalizacion
            ),
            JSON_OBJECT(
                'id_mecanico', NEW.id_mecanico,
                'estado', NEW.estado,
                'diagnostico', NEW.diagnostico,
                'observacion', NEW.observacion,
                'kilometraje_ingreso', NEW.kilometraje_ingreso,
                'inventario_descontado', NEW.inventario_descontado,
                'fecha_finalizacion', NEW.fecha_finalizacion
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita la emisión de una factura.
DROP TRIGGER IF EXISTS trg_factura_ai_auditar$$
CREATE TRIGGER trg_factura_ai_auditar
AFTER INSERT ON factura
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (
        id_usuario, tabla_afectada, id_registro, accion, motivo,
        datos_anteriores, datos_nuevos, origen, direccion_ip
    )
    VALUES (
        @app_id_usuario,
        'factura',
        NEW.id_factura,
        'emision_factura',
        NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
        NULL,
        JSON_OBJECT(
            'id_factura', NEW.id_factura,
            'id_orden_trabajo', NEW.id_orden_trabajo,
            'estado', NEW.estado,
            'fecha_emision', NEW.fecha_emision,
            'subtotal', NEW.subtotal,
            'porcentaje_iva', NEW.porcentaje_iva,
            'valor_iva', NEW.valor_iva,
            'total', NEW.total,
            'id_usuario_emision', NEW.id_usuario_emision,
            'identificacion_cliente', NEW.identificacion_cliente,
            'nombre_cliente', NEW.nombre_cliente,
            'placa_vehiculo', NEW.placa_vehiculo
        ),
        COALESCE(
            NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
            'dml_directo'
        ),
        NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
    );
END$$

-- Audita la anulación u otro cambio permitido de una factura.
DROP TRIGGER IF EXISTS trg_factura_au_auditar$$
CREATE TRIGGER trg_factura_au_auditar
AFTER UPDATE ON factura
FOR EACH ROW
BEGIN
    IF NOT (NEW.estado <=> OLD.estado)
       OR NOT (NEW.fecha_anulacion <=> OLD.fecha_anulacion)
       OR NOT (NEW.id_usuario_anulacion <=> OLD.id_usuario_anulacion)
       OR NOT (NEW.motivo_anulacion <=> OLD.motivo_anulacion) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'factura',
            NEW.id_factura,
            CASE
                WHEN NEW.estado = 'anulada' THEN 'anulacion_factura'
                ELSE 'actualizacion_factura'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'estado', OLD.estado,
                'fecha_anulacion', OLD.fecha_anulacion,
                'id_usuario_anulacion', OLD.id_usuario_anulacion,
                'motivo_anulacion', OLD.motivo_anulacion,
                'total', OLD.total
            ),
            JSON_OBJECT(
                'estado', NEW.estado,
                'fecha_anulacion', NEW.fecha_anulacion,
                'id_usuario_anulacion', NEW.id_usuario_anulacion,
                'motivo_anulacion', NEW.motivo_anulacion,
                'total', NEW.total
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita el registro de un pago.
DROP TRIGGER IF EXISTS trg_pago_ai_auditar$$
CREATE TRIGGER trg_pago_ai_auditar
AFTER INSERT ON pago
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (
        id_usuario, tabla_afectada, id_registro, accion, motivo,
        datos_anteriores, datos_nuevos, origen, direccion_ip
    )
    VALUES (
        @app_id_usuario,
        'pago',
        NEW.id_pago,
        'registro_pago',
        NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
        NULL,
        JSON_OBJECT(
            'id_pago', NEW.id_pago,
            'id_factura', NEW.id_factura,
            'monto', NEW.monto,
            'metodo_pago', NEW.metodo_pago,
            'referencia', NEW.referencia,
            'estado', NEW.estado,
            'fecha_pago', NEW.fecha_pago,
            'id_usuario_registro', NEW.id_usuario_registro
        ),
        COALESCE(
            NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
            'dml_directo'
        ),
        NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
    );
END$$

-- Audita la anulación u otro cambio permitido de un pago.
DROP TRIGGER IF EXISTS trg_pago_au_auditar$$
CREATE TRIGGER trg_pago_au_auditar
AFTER UPDATE ON pago
FOR EACH ROW
BEGIN
    IF NOT (NEW.estado <=> OLD.estado)
       OR NOT (NEW.fecha_anulacion <=> OLD.fecha_anulacion)
       OR NOT (NEW.id_usuario_anulacion <=> OLD.id_usuario_anulacion)
       OR NOT (NEW.motivo_anulacion <=> OLD.motivo_anulacion) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'pago',
            NEW.id_pago,
            CASE
                WHEN NEW.estado = 'anulado' THEN 'anulacion_pago'
                ELSE 'actualizacion_pago'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'estado', OLD.estado,
                'fecha_anulacion', OLD.fecha_anulacion,
                'id_usuario_anulacion', OLD.id_usuario_anulacion,
                'motivo_anulacion', OLD.motivo_anulacion,
                'monto', OLD.monto,
                'metodo_pago', OLD.metodo_pago,
                'referencia', OLD.referencia
            ),
            JSON_OBJECT(
                'estado', NEW.estado,
                'fecha_anulacion', NEW.fecha_anulacion,
                'id_usuario_anulacion', NEW.id_usuario_anulacion,
                'motivo_anulacion', NEW.motivo_anulacion,
                'monto', NEW.monto,
                'metodo_pago', NEW.metodo_pago,
                'referencia', NEW.referencia
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita actualizaciones y cambios de actividad de clientes.
DROP TRIGGER IF EXISTS trg_cliente_au_auditar$$
CREATE TRIGGER trg_cliente_au_auditar
AFTER UPDATE ON cliente
FOR EACH ROW
BEGIN
    IF NOT (NEW.tipo_cliente <=> OLD.tipo_cliente)
       OR NOT (NEW.tipo_identificacion <=> OLD.tipo_identificacion)
       OR NOT (NEW.identificacion <=> OLD.identificacion)
       OR NOT (NEW.nombres <=> OLD.nombres)
       OR NOT (NEW.apellidos <=> OLD.apellidos)
       OR NOT (NEW.razon_social <=> OLD.razon_social)
       OR NOT (NEW.telefono <=> OLD.telefono)
       OR NOT (NEW.correo <=> OLD.correo)
       OR NOT (NEW.direccion <=> OLD.direccion)
       OR NOT (NEW.activo <=> OLD.activo)
       OR NOT (NEW.fecha_desactivacion <=> OLD.fecha_desactivacion) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'cliente',
            NEW.id_cliente,
            CASE
                WHEN OLD.activo = 1 AND NEW.activo = 0 THEN 'desactivacion'
                WHEN OLD.activo = 0 AND NEW.activo = 1 THEN 'reactivacion'
                ELSE 'actualizacion'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'tipo_cliente', OLD.tipo_cliente,
                'tipo_identificacion', OLD.tipo_identificacion,
                'identificacion', OLD.identificacion,
                'nombres', OLD.nombres,
                'apellidos', OLD.apellidos,
                'razon_social', OLD.razon_social,
                'telefono', OLD.telefono,
                'correo', OLD.correo,
                'direccion', OLD.direccion,
                'activo', OLD.activo,
                'fecha_desactivacion', OLD.fecha_desactivacion
            ),
            JSON_OBJECT(
                'tipo_cliente', NEW.tipo_cliente,
                'tipo_identificacion', NEW.tipo_identificacion,
                'identificacion', NEW.identificacion,
                'nombres', NEW.nombres,
                'apellidos', NEW.apellidos,
                'razon_social', NEW.razon_social,
                'telefono', NEW.telefono,
                'correo', NEW.correo,
                'direccion', NEW.direccion,
                'activo', NEW.activo,
                'fecha_desactivacion', NEW.fecha_desactivacion
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita cambios de vehículo, propietario y actividad.
DROP TRIGGER IF EXISTS trg_vehiculo_au_auditar$$
CREATE TRIGGER trg_vehiculo_au_auditar
AFTER UPDATE ON vehiculo
FOR EACH ROW
BEGIN
    IF NOT (NEW.id_cliente <=> OLD.id_cliente)
       OR NOT (NEW.placa <=> OLD.placa)
       OR NOT (NEW.numero_chasis <=> OLD.numero_chasis)
       OR NOT (NEW.marca <=> OLD.marca)
       OR NOT (NEW.modelo <=> OLD.modelo)
       OR NOT (NEW.anio <=> OLD.anio)
       OR NOT (NEW.color <=> OLD.color)
       OR NOT (NEW.kilometraje_actual <=> OLD.kilometraje_actual)
       OR NOT (NEW.activo <=> OLD.activo)
       OR NOT (NEW.fecha_desactivacion <=> OLD.fecha_desactivacion) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'vehiculo',
            NEW.id_vehiculo,
            CASE
                WHEN OLD.activo = 1 AND NEW.activo = 0 THEN 'desactivacion'
                WHEN OLD.activo = 0 AND NEW.activo = 1 THEN 'reactivacion'
                WHEN NOT (NEW.id_cliente <=> OLD.id_cliente)
                    THEN 'cambio_propietario'
                ELSE 'actualizacion'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'id_cliente', OLD.id_cliente,
                'placa', OLD.placa,
                'numero_chasis', OLD.numero_chasis,
                'marca', OLD.marca,
                'modelo', OLD.modelo,
                'anio', OLD.anio,
                'color', OLD.color,
                'kilometraje_actual', OLD.kilometraje_actual,
                'activo', OLD.activo,
                'fecha_desactivacion', OLD.fecha_desactivacion
            ),
            JSON_OBJECT(
                'id_cliente', NEW.id_cliente,
                'placa', NEW.placa,
                'numero_chasis', NEW.numero_chasis,
                'marca', NEW.marca,
                'modelo', NEW.modelo,
                'anio', NEW.anio,
                'color', NEW.color,
                'kilometraje_actual', NEW.kilometraje_actual,
                'activo', NEW.activo,
                'fecha_desactivacion', NEW.fecha_desactivacion
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita la creación de usuarios sin exponer su hash de contraseña.
DROP TRIGGER IF EXISTS trg_usuario_ai_auditar$$
CREATE TRIGGER trg_usuario_ai_auditar
AFTER INSERT ON usuario
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (
        id_usuario, tabla_afectada, id_registro, accion, motivo,
        datos_anteriores, datos_nuevos, origen, direccion_ip
    )
    VALUES (
        @app_id_usuario,
        'usuario',
        NEW.id_usuario,
        'creacion_usuario',
        NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
        NULL,
        JSON_OBJECT(
            'id_usuario', NEW.id_usuario,
            'id_rol', NEW.id_rol,
            'cedula', NEW.cedula,
            'nombre_usuario', NEW.nombre_usuario,
            'nombres', NEW.nombres,
            'apellidos', NEW.apellidos,
            'correo', NEW.correo,
            'telefono', NEW.telefono,
            'activo', NEW.activo,
            'fecha_creacion', NEW.fecha_creacion
        ),
        COALESCE(
            NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
            'dml_directo'
        ),
        NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
    );
END$$

-- Audita cambios de usuario sin almacenar hashes.
DROP TRIGGER IF EXISTS trg_usuario_au_auditar$$
CREATE TRIGGER trg_usuario_au_auditar
AFTER UPDATE ON usuario
FOR EACH ROW
BEGIN
    IF NOT (NEW.id_rol <=> OLD.id_rol)
       OR NOT (NEW.cedula <=> OLD.cedula)
       OR NOT (NEW.nombre_usuario <=> OLD.nombre_usuario)
       OR NOT (NEW.password_hash <=> OLD.password_hash)
       OR NOT (NEW.nombres <=> OLD.nombres)
       OR NOT (NEW.apellidos <=> OLD.apellidos)
       OR NOT (NEW.correo <=> OLD.correo)
       OR NOT (NEW.telefono <=> OLD.telefono)
       OR NOT (NEW.activo <=> OLD.activo)
       OR NOT (NEW.fecha_desactivacion <=> OLD.fecha_desactivacion) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'usuario',
            NEW.id_usuario,
            CASE
                WHEN OLD.activo = 1 AND NEW.activo = 0 THEN 'desactivacion'
                WHEN OLD.activo = 0 AND NEW.activo = 1 THEN 'reactivacion'
                WHEN NOT (NEW.id_rol <=> OLD.id_rol) THEN 'cambio_rol'
                WHEN NOT (NEW.password_hash <=> OLD.password_hash)
                    THEN 'cambio_password'
                ELSE 'actualizacion'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'id_rol', OLD.id_rol,
                'cedula', OLD.cedula,
                'nombre_usuario', OLD.nombre_usuario,
                'nombres', OLD.nombres,
                'apellidos', OLD.apellidos,
                'correo', OLD.correo,
                'telefono', OLD.telefono,
                'activo', OLD.activo,
                'fecha_desactivacion', OLD.fecha_desactivacion,
                'password_hash_cambiado', 0
            ),
            JSON_OBJECT(
                'id_rol', NEW.id_rol,
                'cedula', NEW.cedula,
                'nombre_usuario', NEW.nombre_usuario,
                'nombres', NEW.nombres,
                'apellidos', NEW.apellidos,
                'correo', NEW.correo,
                'telefono', NEW.telefono,
                'activo', NEW.activo,
                'fecha_desactivacion', NEW.fecha_desactivacion,
                'password_hash_cambiado',
                    CASE
                        WHEN NOT (NEW.password_hash <=> OLD.password_hash)
                            THEN 1
                        ELSE 0
                    END
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita cambios en el catálogo de roles.
DROP TRIGGER IF EXISTS trg_rol_au_auditar$$
CREATE TRIGGER trg_rol_au_auditar
AFTER UPDATE ON rol
FOR EACH ROW
BEGIN
    IF NOT (NEW.nombre <=> OLD.nombre)
       OR NOT (NEW.descripcion <=> OLD.descripcion)
       OR NOT (NEW.activo <=> OLD.activo) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'rol',
            NEW.id_rol,
            CASE
                WHEN OLD.activo = 1 AND NEW.activo = 0 THEN 'desactivacion'
                WHEN OLD.activo = 0 AND NEW.activo = 1 THEN 'reactivacion'
                ELSE 'actualizacion'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'nombre', OLD.nombre,
                'descripcion', OLD.descripcion,
                'activo', OLD.activo
            ),
            JSON_OBJECT(
                'nombre', NEW.nombre,
                'descripcion', NEW.descripcion,
                'activo', NEW.activo
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita cambios en perfiles de mecánico.
DROP TRIGGER IF EXISTS trg_mecanico_au_auditar$$
CREATE TRIGGER trg_mecanico_au_auditar
AFTER UPDATE ON mecanico
FOR EACH ROW
BEGIN
    IF NOT (NEW.id_usuario <=> OLD.id_usuario)
       OR NOT (NEW.especialidad <=> OLD.especialidad)
       OR NOT (NEW.nivel <=> OLD.nivel)
       OR NOT (NEW.maximo_ordenes_activas <=> OLD.maximo_ordenes_activas)
       OR NOT (NEW.disponibilidad <=> OLD.disponibilidad)
       OR NOT (NEW.activo <=> OLD.activo) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'mecanico',
            NEW.id_mecanico,
            CASE
                WHEN OLD.activo = 1 AND NEW.activo = 0 THEN 'desactivacion'
                WHEN OLD.activo = 0 AND NEW.activo = 1 THEN 'reactivacion'
                ELSE 'actualizacion'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'id_usuario', OLD.id_usuario,
                'especialidad', OLD.especialidad,
                'nivel', OLD.nivel,
                'maximo_ordenes_activas', OLD.maximo_ordenes_activas,
                'disponibilidad', OLD.disponibilidad,
                'activo', OLD.activo
            ),
            JSON_OBJECT(
                'id_usuario', NEW.id_usuario,
                'especialidad', NEW.especialidad,
                'nivel', NEW.nivel,
                'maximo_ordenes_activas', NEW.maximo_ordenes_activas,
                'disponibilidad', NEW.disponibilidad,
                'activo', NEW.activo
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita cambios en el catálogo de servicios.
DROP TRIGGER IF EXISTS trg_servicio_au_auditar$$
CREATE TRIGGER trg_servicio_au_auditar
AFTER UPDATE ON servicio
FOR EACH ROW
BEGIN
    IF NOT (NEW.codigo <=> OLD.codigo)
       OR NOT (NEW.nombre <=> OLD.nombre)
       OR NOT (NEW.categoria <=> OLD.categoria)
       OR NOT (
           NEW.duracion_estimada_minutos
           <=> OLD.duracion_estimada_minutos
       )
       OR NOT (NEW.descripcion <=> OLD.descripcion)
       OR NOT (NEW.activo <=> OLD.activo) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'servicio',
            NEW.id_servicio,
            CASE
                WHEN OLD.activo = 1 AND NEW.activo = 0 THEN 'desactivacion'
                WHEN OLD.activo = 0 AND NEW.activo = 1 THEN 'reactivacion'
                ELSE 'actualizacion'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'codigo', OLD.codigo,
                'nombre', OLD.nombre,
                'categoria', OLD.categoria,
                'duracion_estimada_minutos',
                    OLD.duracion_estimada_minutos,
                'descripcion', OLD.descripcion,
                'activo', OLD.activo
            ),
            JSON_OBJECT(
                'codigo', NEW.codigo,
                'nombre', NEW.nombre,
                'categoria', NEW.categoria,
                'duracion_estimada_minutos',
                    NEW.duracion_estimada_minutos,
                'descripcion', NEW.descripcion,
                'activo', NEW.activo
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

-- Audita cambios de catálogo y movimientos de stock de repuestos.
DROP TRIGGER IF EXISTS trg_repuesto_au_auditar$$
CREATE TRIGGER trg_repuesto_au_auditar
AFTER UPDATE ON repuesto
FOR EACH ROW
BEGIN
    IF NOT (NEW.codigo <=> OLD.codigo)
       OR NOT (NEW.nombre <=> OLD.nombre)
       OR NOT (NEW.marca <=> OLD.marca)
       OR NOT (NEW.descripcion <=> OLD.descripcion)
       OR NOT (NEW.stock_actual <=> OLD.stock_actual)
       OR NOT (NEW.stock_minimo <=> OLD.stock_minimo)
       OR NOT (NEW.unidad_medida <=> OLD.unidad_medida)
       OR NOT (NEW.activo <=> OLD.activo) THEN
        INSERT INTO auditoria (
            id_usuario, tabla_afectada, id_registro, accion, motivo,
            datos_anteriores, datos_nuevos, origen, direccion_ip
        )
        VALUES (
            @app_id_usuario,
            'repuesto',
            NEW.id_repuesto,
            CASE
                WHEN OLD.activo = 1 AND NEW.activo = 0 THEN 'desactivacion'
                WHEN OLD.activo = 0 AND NEW.activo = 1 THEN 'reactivacion'
                WHEN NOT (NEW.stock_actual <=> OLD.stock_actual)
                    THEN 'movimiento_stock'
                ELSE 'actualizacion'
            END,
            NULLIF(TRIM(COALESCE(@app_motivo, '')), ''),
            JSON_OBJECT(
                'codigo', OLD.codigo,
                'nombre', OLD.nombre,
                'marca', OLD.marca,
                'descripcion', OLD.descripcion,
                'stock_actual', OLD.stock_actual,
                'stock_minimo', OLD.stock_minimo,
                'unidad_medida', OLD.unidad_medida,
                'activo', OLD.activo
            ),
            JSON_OBJECT(
                'codigo', NEW.codigo,
                'nombre', NEW.nombre,
                'marca', NEW.marca,
                'descripcion', NEW.descripcion,
                'stock_actual', NEW.stock_actual,
                'stock_minimo', NEW.stock_minimo,
                'unidad_medida', NEW.unidad_medida,
                'activo', NEW.activo
            ),
            COALESCE(
                NULLIF(TRIM(COALESCE(@app_origen, '')), ''),
                'dml_directo'
            ),
            NULLIF(LEFT(SUBSTRING_INDEX(USER(), '@', -1), 45), '')
        );
    END IF;
END$$

DELIMITER ;