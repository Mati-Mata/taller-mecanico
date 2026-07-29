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

DELIMITER ;
