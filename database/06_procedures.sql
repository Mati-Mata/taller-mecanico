-- Fase 5A: primeros procedimientos almacenados transaccionales.
-- Se ejecuta después de crear las vistas de consulta.

USE taller_mecanico;

DELIMITER $$

-- Crea un cliente y su primer vehículo como una sola unidad transaccional.
DROP PROCEDURE IF EXISTS sp_crear_cliente_vehiculo$$
CREATE PROCEDURE sp_crear_cliente_vehiculo (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_tipo_cliente VARCHAR(10),
    IN p_tipo_identificacion VARCHAR(10),
    IN p_identificacion VARCHAR(13),
    IN p_nombres VARCHAR(100),
    IN p_apellidos VARCHAR(100),
    IN p_razon_social VARCHAR(150),
    IN p_telefono VARCHAR(20),
    IN p_correo VARCHAR(254),
    IN p_direccion VARCHAR(255),
    IN p_placa VARCHAR(10),
    IN p_numero_chasis VARCHAR(50),
    IN p_marca VARCHAR(60),
    IN p_modelo VARCHAR(60),
    IN p_anio SMALLINT UNSIGNED,
    IN p_color VARCHAR(40),
    IN p_kilometraje_actual INT UNSIGNED,
    OUT p_id_cliente_creado INT UNSIGNED,
    OUT p_id_vehiculo_creado INT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_identificacion VARCHAR(13);
    DECLARE v_nombres VARCHAR(100);
    DECLARE v_apellidos VARCHAR(100);
    DECLARE v_razon_social VARCHAR(150);
    DECLARE v_telefono VARCHAR(20);
    DECLARE v_correo VARCHAR(254);
    DECLARE v_direccion VARCHAR(255);
    DECLARE v_placa VARCHAR(10);
    DECLARE v_numero_chasis VARCHAR(50);
    DECLARE v_marca VARCHAR(60);
    DECLARE v_modelo VARCHAR(60);
    DECLARE v_color VARCHAR(40);
    DECLARE v_duplicados INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_cliente_creado = NULL;
        SET p_id_vehiculo_creado = NULL;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_id_cliente_creado = NULL;
    SET p_id_vehiculo_creado = NULL;

    IF p_id_usuario_actor IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario actor es obligatorio';
    END IF;

    IF p_tipo_cliente IS NULL OR p_tipo_identificacion IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El tipo de cliente e identificacion son obligatorios';
    END IF;

    IF p_kilometraje_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El kilometraje actual es obligatorio';
    END IF;

    SET v_identificacion = TRIM(p_identificacion);
    SET v_nombres = NULLIF(TRIM(p_nombres), '');
    SET v_apellidos = NULLIF(TRIM(p_apellidos), '');
    SET v_razon_social = NULLIF(TRIM(p_razon_social), '');
    SET v_telefono = TRIM(p_telefono);
    SET v_correo = NULLIF(LOWER(TRIM(p_correo)), '');
    SET v_direccion = NULLIF(TRIM(p_direccion), '');
    SET v_placa = UPPER(TRIM(p_placa));
    SET v_numero_chasis = NULLIF(UPPER(TRIM(p_numero_chasis)), '');
    SET v_marca = TRIM(p_marca);
    SET v_modelo = TRIM(p_modelo);
    SET v_color = NULLIF(TRIM(p_color), '');

    IF v_identificacion IS NULL OR v_identificacion = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La identificacion es obligatoria';
    END IF;

    IF v_telefono IS NULL OR v_telefono = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El telefono es obligatorio';
    END IF;

    IF v_placa IS NULL OR v_placa = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La placa es obligatoria';
    END IF;

    IF v_marca IS NULL OR v_marca = ''
       OR v_modelo IS NULL OR v_modelo = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La marca y el modelo son obligatorios';
    END IF;

    SELECT COUNT(*)
      INTO v_actor_valido
      FROM usuario AS u
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = p_id_usuario_actor
       AND u.activo = 1
       AND r.activo = 1
       AND r.nombre IN ('administrador', 'asesor');

    IF v_actor_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor debe ser administrador o asesor activo';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_crear_cliente_vehiculo';
    SET @app_motivo = NULL;

    START TRANSACTION;

    SELECT COUNT(*)
      INTO v_duplicados
      FROM cliente AS c
     WHERE c.identificacion = v_identificacion;

    IF v_duplicados > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existe un cliente con esa identificacion';
    END IF;

    SELECT COUNT(*)
      INTO v_duplicados
      FROM vehiculo AS v
     WHERE v.placa = v_placa;

    IF v_duplicados > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existe un vehiculo con esa placa';
    END IF;

    IF v_numero_chasis IS NOT NULL THEN
        SELECT COUNT(*)
          INTO v_duplicados
          FROM vehiculo AS v
         WHERE v.numero_chasis = v_numero_chasis;

        IF v_duplicados > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ya existe un vehiculo con ese numero de chasis';
        END IF;
    END IF;

    INSERT INTO cliente (
        tipo_cliente,
        tipo_identificacion,
        identificacion,
        nombres,
        apellidos,
        razon_social,
        telefono,
        correo,
        direccion
    )
    VALUES (
        TRIM(p_tipo_cliente),
        TRIM(p_tipo_identificacion),
        v_identificacion,
        v_nombres,
        v_apellidos,
        v_razon_social,
        v_telefono,
        v_correo,
        v_direccion
    );

    SET p_id_cliente_creado = LAST_INSERT_ID();

    INSERT INTO vehiculo (
        id_cliente,
        placa,
        numero_chasis,
        marca,
        modelo,
        anio,
        color,
        kilometraje_actual
    )
    VALUES (
        p_id_cliente_creado,
        v_placa,
        v_numero_chasis,
        v_marca,
        v_modelo,
        p_anio,
        v_color,
        p_kilometraje_actual
    );

    SET p_id_vehiculo_creado = LAST_INSERT_ID();

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Cierra el precio vigente e inserta uno nuevo serializando por concepto.
DROP PROCEDURE IF EXISTS sp_registrar_precio$$
CREATE PROCEDURE sp_registrar_precio (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_tipo_concepto VARCHAR(10),
    IN p_id_concepto INT UNSIGNED,
    IN p_costo_base DECIMAL(12,2),
    IN p_precio_venta DECIMAL(12,2),
    IN p_fecha_inicio DATETIME,
    OUT p_id_historial_precio_creado INT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_tipo_concepto VARCHAR(10);
    DECLARE v_fecha_inicio DATETIME;
    DECLARE v_concepto_activo TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_mayor_fecha_inicio DATETIME DEFAULT NULL;
    DECLARE v_precios_vigentes INT DEFAULT 0;
    DECLARE v_id_precio_vigente INT UNSIGNED DEFAULT NULL;
    DECLARE v_fecha_precio_vigente DATETIME DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_historial_precio_creado = NULL;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_id_historial_precio_creado = NULL;
    SET v_tipo_concepto = LOWER(TRIM(p_tipo_concepto));
    SET v_fecha_inicio = COALESCE(p_fecha_inicio, CURRENT_TIMESTAMP);

    IF p_id_usuario_actor IS NULL OR p_id_concepto IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor y el concepto son obligatorios';
    END IF;

    IF v_tipo_concepto NOT IN ('servicio', 'repuesto')
       OR v_tipo_concepto IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El tipo de concepto debe ser servicio o repuesto';
    END IF;

    IF p_costo_base IS NULL OR p_precio_venta IS NULL
       OR p_costo_base < 0 OR p_precio_venta < p_costo_base THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El costo y el precio de venta no son validos';
    END IF;

    SELECT COUNT(*)
      INTO v_actor_valido
      FROM usuario AS u
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = p_id_usuario_actor
       AND u.activo = 1
       AND r.activo = 1
       AND r.nombre = 'administrador';

    IF v_actor_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo un administrador activo puede registrar precios';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_registrar_precio';
    SET @app_motivo = NULL;

    START TRANSACTION;

    -- El bloqueo del catálogo serializa todos los cambios del mismo concepto.
    IF v_tipo_concepto = 'servicio' THEN
        SET v_concepto_activo = NULL;

        SELECT s.activo
          INTO v_concepto_activo
          FROM servicio AS s
         WHERE s.id_servicio = p_id_concepto
         FOR UPDATE;

        IF v_concepto_activo IS NULL OR v_concepto_activo <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El servicio no existe o esta inactivo';
        END IF;

        SELECT MAX(hp.fecha_inicio),
               COALESCE(SUM(hp.fecha_fin IS NULL), 0)
          INTO v_mayor_fecha_inicio, v_precios_vigentes
          FROM historial_precio AS hp
         WHERE hp.id_servicio = p_id_concepto;
    ELSE
        SET v_concepto_activo = NULL;

        SELECT r.activo
          INTO v_concepto_activo
          FROM repuesto AS r
         WHERE r.id_repuesto = p_id_concepto
         FOR UPDATE;

        IF v_concepto_activo IS NULL OR v_concepto_activo <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El repuesto no existe o esta inactivo';
        END IF;

        SELECT MAX(hp.fecha_inicio),
               COALESCE(SUM(hp.fecha_fin IS NULL), 0)
          INTO v_mayor_fecha_inicio, v_precios_vigentes
          FROM historial_precio AS hp
         WHERE hp.id_repuesto = p_id_concepto;
    END IF;

    IF v_mayor_fecha_inicio IS NOT NULL
       AND v_fecha_inicio <= v_mayor_fecha_inicio THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La fecha nueva debe ser posterior al historial existente';
    END IF;

    IF v_precios_vigentes > 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Existe mas de un precio vigente para el concepto';
    END IF;

    IF v_precios_vigentes = 1 THEN
        SET v_id_precio_vigente = NULL;
        SET v_fecha_precio_vigente = NULL;

        IF v_tipo_concepto = 'servicio' THEN
            SELECT hp.id_historial_precio, hp.fecha_inicio
              INTO v_id_precio_vigente, v_fecha_precio_vigente
              FROM historial_precio AS hp
             WHERE hp.id_servicio = p_id_concepto
               AND hp.fecha_fin IS NULL
             FOR UPDATE;
        ELSE
            SELECT hp.id_historial_precio, hp.fecha_inicio
              INTO v_id_precio_vigente, v_fecha_precio_vigente
              FROM historial_precio AS hp
             WHERE hp.id_repuesto = p_id_concepto
               AND hp.fecha_fin IS NULL
             FOR UPDATE;
        END IF;

        IF v_fecha_inicio <= v_fecha_precio_vigente THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La fecha nueva debe ser posterior al precio vigente';
        END IF;

        UPDATE historial_precio AS hp
           SET fecha_fin = v_fecha_inicio
         WHERE hp.id_historial_precio = v_id_precio_vigente;
    END IF;

    IF v_tipo_concepto = 'servicio' THEN
        INSERT INTO historial_precio (
            id_servicio,
            id_repuesto,
            costo_base,
            precio_venta,
            fecha_inicio,
            fecha_fin,
            id_usuario_creador
        )
        VALUES (
            p_id_concepto,
            NULL,
            p_costo_base,
            p_precio_venta,
            v_fecha_inicio,
            NULL,
            p_id_usuario_actor
        );
    ELSE
        INSERT INTO historial_precio (
            id_servicio,
            id_repuesto,
            costo_base,
            precio_venta,
            fecha_inicio,
            fecha_fin,
            id_usuario_creador
        )
        VALUES (
            NULL,
            p_id_concepto,
            p_costo_base,
            p_precio_venta,
            v_fecha_inicio,
            NULL,
            p_id_usuario_actor
        );
    END IF;

    SET p_id_historial_precio_creado = LAST_INSERT_ID();

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Abre una orden, registra su estado inicial y actualiza el kilometraje.
DROP PROCEDURE IF EXISTS sp_crear_orden_trabajo$$
CREATE PROCEDURE sp_crear_orden_trabajo (
    IN p_id_usuario_apertura INT UNSIGNED,
    IN p_id_vehiculo INT UNSIGNED,
    IN p_id_mecanico INT UNSIGNED,
    IN p_descripcion_problema TEXT,
    IN p_observacion TEXT,
    IN p_kilometraje_ingreso INT UNSIGNED,
    OUT p_id_orden_trabajo_creada INT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_vehiculo_activo TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_cliente_activo TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_kilometraje_actual INT UNSIGNED DEFAULT NULL;
    DECLARE v_mecanico_activo TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_disponibilidad VARCHAR(20) DEFAULT NULL;
    DECLARE v_maximo_ordenes TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_usuario_mecanico_activo TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_rol_mecanico VARCHAR(30) DEFAULT NULL;
    DECLARE v_ordenes_activas INT DEFAULT 0;
    DECLARE v_descripcion TEXT;
    DECLARE v_observacion TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_orden_trabajo_creada = NULL;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_id_orden_trabajo_creada = NULL;
    SET v_descripcion = TRIM(p_descripcion_problema);
    SET v_observacion = NULLIF(TRIM(p_observacion), '');

    IF p_id_usuario_apertura IS NULL
       OR p_id_vehiculo IS NULL
       OR p_id_mecanico IS NULL
       OR p_kilometraje_ingreso IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuario, vehiculo, mecanico y kilometraje son obligatorios';
    END IF;

    IF v_descripcion IS NULL OR v_descripcion = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La descripcion del problema es obligatoria';
    END IF;

    SELECT COUNT(*)
      INTO v_actor_valido
      FROM usuario AS u
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = p_id_usuario_apertura
       AND u.activo = 1
       AND r.activo = 1
       AND r.nombre IN ('administrador', 'asesor');

    IF v_actor_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La apertura requiere administrador o asesor activo';
    END IF;

    SET @app_id_usuario = p_id_usuario_apertura;
    SET @app_origen = 'sp_crear_orden_trabajo';
    SET @app_motivo = NULL;

    START TRANSACTION;

    -- Se bloquean vehículo y cliente antes de comparar y actualizar kilometraje.
    SELECT v.activo, c.activo, v.kilometraje_actual
      INTO v_vehiculo_activo, v_cliente_activo, v_kilometraje_actual
      FROM vehiculo AS v
      INNER JOIN cliente AS c ON c.id_cliente = v.id_cliente
     WHERE v.id_vehiculo = p_id_vehiculo
     FOR UPDATE;

    IF v_vehiculo_activo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El vehiculo no existe';
    END IF;

    IF v_vehiculo_activo <> 1 OR v_cliente_activo <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El vehiculo y su cliente deben estar activos';
    END IF;

    IF p_kilometraje_ingreso < v_kilometraje_actual THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El kilometraje no puede disminuir';
    END IF;

    -- El bloqueo del mecánico serializa la comprobación de su capacidad.
    SELECT m.activo,
           m.disponibilidad,
           m.maximo_ordenes_activas,
           u.activo,
           r.nombre
      INTO v_mecanico_activo,
           v_disponibilidad,
           v_maximo_ordenes,
           v_usuario_mecanico_activo,
           v_rol_mecanico
      FROM mecanico AS m
      INNER JOIN usuario AS u ON u.id_usuario = m.id_usuario
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
     WHERE m.id_mecanico = p_id_mecanico
     FOR UPDATE;

    IF v_mecanico_activo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El mecanico no existe';
    END IF;

    IF v_mecanico_activo <> 1
       OR v_disponibilidad <> 'disponible'
       OR v_usuario_mecanico_activo <> 1
       OR v_rol_mecanico <> 'mecanico' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El mecanico no esta habilitado y disponible';
    END IF;

    SELECT COUNT(*)
      INTO v_ordenes_activas
      FROM orden_trabajo AS ot
     WHERE ot.id_mecanico = p_id_mecanico
       AND ot.estado IN (
           'ingresada',
           'diagnostico',
           'esperando_repuestos',
           'en_reparacion'
       );

    IF v_ordenes_activas >= v_maximo_ordenes THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El mecanico alcanzo su limite de ordenes activas';
    END IF;

    INSERT INTO orden_trabajo (
        id_vehiculo,
        id_mecanico,
        id_usuario_apertura,
        estado,
        descripcion_problema,
        diagnostico,
        observacion,
        kilometraje_ingreso,
        inventario_descontado,
        fecha_finalizacion
    )
    VALUES (
        p_id_vehiculo,
        p_id_mecanico,
        p_id_usuario_apertura,
        'ingresada',
        v_descripcion,
        NULL,
        v_observacion,
        p_kilometraje_ingreso,
        0,
        NULL
    );

    SET p_id_orden_trabajo_creada = LAST_INSERT_ID();

    INSERT INTO historial_estado_orden (
        id_orden_trabajo,
        estado_anterior,
        estado_nuevo,
        id_usuario,
        observacion
    )
    VALUES (
        p_id_orden_trabajo_creada,
        NULL,
        'ingresada',
        p_id_usuario_apertura,
        NULL
    );

    UPDATE vehiculo AS v
       SET kilometraje_actual = p_kilometraje_ingreso
     WHERE v.id_vehiculo = p_id_vehiculo;

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Agrega un concepto a una orden usando su precio vigente como instantánea.
DROP PROCEDURE IF EXISTS sp_agregar_detalle_orden$$
CREATE PROCEDURE sp_agregar_detalle_orden (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_id_orden_trabajo INT UNSIGNED,
    IN p_tipo_concepto VARCHAR(10),
    IN p_id_concepto INT UNSIGNED,
    IN p_cantidad DECIMAL(12,2),
    IN p_observacion VARCHAR(500),
    OUT p_id_detalle_orden_creado INT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_rol_actor VARCHAR(30) DEFAULT NULL;
    DECLARE v_id_mecanico_actor INT UNSIGNED DEFAULT NULL;
    DECLARE v_estado_orden VARCHAR(25) DEFAULT NULL;
    DECLARE v_id_mecanico_orden INT UNSIGNED DEFAULT NULL;
    DECLARE v_tipo_concepto VARCHAR(10);
    DECLARE v_concepto_activo TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_codigo VARCHAR(40) DEFAULT NULL;
    DECLARE v_nombre VARCHAR(120) DEFAULT NULL;
    DECLARE v_stock_actual DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_precios_vigentes INT DEFAULT 0;
    DECLARE v_id_historial_precio INT UNSIGNED DEFAULT NULL;
    DECLARE v_precio_venta DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_id_servicio INT UNSIGNED DEFAULT NULL;
    DECLARE v_id_repuesto INT UNSIGNED DEFAULT NULL;
    DECLARE v_observacion VARCHAR(500) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_detalle_orden_creado = NULL;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_id_detalle_orden_creado = NULL;
    SET v_tipo_concepto = LOWER(TRIM(p_tipo_concepto));
    SET v_observacion = NULLIF(TRIM(p_observacion), '');

    IF p_id_usuario_actor IS NULL
       OR p_id_orden_trabajo IS NULL
       OR p_id_concepto IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Actor, orden y concepto son obligatorios';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cantidad debe ser mayor que cero';
    END IF;

    IF v_tipo_concepto NOT IN ('servicio', 'repuesto')
       OR v_tipo_concepto IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El tipo de concepto debe ser servicio o repuesto';
    END IF;

    SELECT COUNT(*), MAX(r.nombre), MAX(m.id_mecanico)
      INTO v_actor_valido, v_rol_actor, v_id_mecanico_actor
      FROM usuario AS u
      INNER JOIN rol AS r ON r.id_rol = u.id_rol
      LEFT JOIN mecanico AS m
        ON m.id_usuario = u.id_usuario
       AND m.activo = 1
     WHERE u.id_usuario = p_id_usuario_actor
       AND u.activo = 1
       AND r.activo = 1
       AND r.nombre IN ('administrador', 'asesor', 'mecanico');

    IF v_actor_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor no existe, esta inactivo o no tiene rol permitido';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_agregar_detalle_orden';
    SET @app_motivo = NULL;

    START TRANSACTION;

    -- La orden se bloquea antes de validar estado y responsabilidad.
    SELECT ot.estado, ot.id_mecanico
      INTO v_estado_orden, v_id_mecanico_orden
      FROM orden_trabajo AS ot
     WHERE ot.id_orden_trabajo = p_id_orden_trabajo
     FOR UPDATE;

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

    IF v_rol_actor = 'mecanico'
       AND (
           v_id_mecanico_actor IS NULL
           OR v_id_mecanico_actor <> v_id_mecanico_orden
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El mecanico actor no es responsable de la orden';
    END IF;

    -- El catálogo se bloquea antes de seleccionar el precio vigente.
    IF v_tipo_concepto = 'servicio' THEN
        SELECT s.activo, s.codigo, s.nombre
          INTO v_concepto_activo, v_codigo, v_nombre
          FROM servicio AS s
         WHERE s.id_servicio = p_id_concepto
         FOR UPDATE;

        IF v_concepto_activo IS NULL OR v_concepto_activo <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El servicio no existe o esta inactivo';
        END IF;

        SELECT COUNT(*)
          INTO v_precios_vigentes
          FROM historial_precio AS hp
         WHERE hp.id_servicio = p_id_concepto
           AND hp.fecha_fin IS NULL;

        IF v_precios_vigentes <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El servicio debe tener exactamente un precio vigente';
        END IF;

        SELECT hp.id_historial_precio, hp.precio_venta
          INTO v_id_historial_precio, v_precio_venta
          FROM historial_precio AS hp
         WHERE hp.id_servicio = p_id_concepto
           AND hp.fecha_fin IS NULL
         FOR UPDATE;

        SET v_id_servicio = p_id_concepto;
        SET v_id_repuesto = NULL;
    ELSE
        SELECT r.activo, r.codigo, r.nombre, r.stock_actual
          INTO v_concepto_activo, v_codigo, v_nombre, v_stock_actual
          FROM repuesto AS r
         WHERE r.id_repuesto = p_id_concepto
         FOR UPDATE;

        IF v_concepto_activo IS NULL OR v_concepto_activo <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El repuesto no existe o esta inactivo';
        END IF;

        IF v_stock_actual < p_cantidad THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El stock actual es insuficiente para el detalle';
        END IF;

        SELECT COUNT(*)
          INTO v_precios_vigentes
          FROM historial_precio AS hp
         WHERE hp.id_repuesto = p_id_concepto
           AND hp.fecha_fin IS NULL;

        IF v_precios_vigentes <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El repuesto debe tener exactamente un precio vigente';
        END IF;

        SELECT hp.id_historial_precio, hp.precio_venta
          INTO v_id_historial_precio, v_precio_venta
          FROM historial_precio AS hp
         WHERE hp.id_repuesto = p_id_concepto
           AND hp.fecha_fin IS NULL
         FOR UPDATE;

        SET v_id_servicio = NULL;
        SET v_id_repuesto = p_id_concepto;
    END IF;

    INSERT INTO detalle_orden (
        id_orden_trabajo,
        id_servicio,
        id_repuesto,
        id_historial_precio,
        descripcion_concepto,
        cantidad,
        precio_unitario,
        subtotal,
        observacion
    )
    VALUES (
        p_id_orden_trabajo,
        v_id_servicio,
        v_id_repuesto,
        v_id_historial_precio,
        v_nombre,
        p_cantidad,
        v_precio_venta,
        ROUND(p_cantidad * v_precio_venta, 2),
        v_observacion
    );

    SET p_id_detalle_orden_creado = LAST_INSERT_ID();

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

DELIMITER ;
