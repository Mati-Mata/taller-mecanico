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

-- Actualiza diagnóstico y observación sin alterar el estado de la orden.
DROP PROCEDURE IF EXISTS sp_actualizar_diagnostico_orden$$
CREATE PROCEDURE sp_actualizar_diagnostico_orden (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_id_orden_trabajo INT UNSIGNED,
    IN p_diagnostico TEXT,
    IN p_observacion TEXT,
    OUT p_actualizada TINYINT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_rol_actor VARCHAR(30) DEFAULT NULL;
    DECLARE v_id_mecanico_actor INT UNSIGNED DEFAULT NULL;
    DECLARE v_estado_orden VARCHAR(25) DEFAULT NULL;
    DECLARE v_id_mecanico_orden INT UNSIGNED DEFAULT NULL;
    DECLARE v_diagnostico TEXT;
    DECLARE v_observacion TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_actualizada = 0;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_actualizada = 0;
    SET v_diagnostico = TRIM(p_diagnostico);
    SET v_observacion = NULLIF(TRIM(p_observacion), '');

    IF p_id_usuario_actor IS NULL OR p_id_orden_trabajo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor y la orden son obligatorios';
    END IF;

    IF v_diagnostico IS NULL OR v_diagnostico = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El diagnostico es obligatorio';
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

    IF v_rol_actor = 'mecanico' AND v_id_mecanico_actor IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor mecanico no tiene un perfil activo';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_actualizar_diagnostico_orden';
    SET @app_motivo = v_observacion;

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
            SET MESSAGE_TEXT = 'La orden no admite actualizar el diagnostico';
    END IF;

    IF v_rol_actor = 'mecanico'
       AND v_id_mecanico_actor <> v_id_mecanico_orden THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El mecanico actor no es responsable de la orden';
    END IF;

    UPDATE orden_trabajo AS ot
       SET diagnostico = v_diagnostico,
           observacion = v_observacion
     WHERE ot.id_orden_trabajo = p_id_orden_trabajo;

    SET p_actualizada = 1;

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Aplica una transición operativa permitida y registra su historial.
DROP PROCEDURE IF EXISTS sp_cambiar_estado_orden$$
CREATE PROCEDURE sp_cambiar_estado_orden (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_id_orden_trabajo INT UNSIGNED,
    IN p_estado_nuevo VARCHAR(25),
    IN p_observacion VARCHAR(500),
    OUT p_id_historial_estado_creado INT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_rol_actor VARCHAR(30) DEFAULT NULL;
    DECLARE v_id_mecanico_actor INT UNSIGNED DEFAULT NULL;
    DECLARE v_estado_actual VARCHAR(25) DEFAULT NULL;
    DECLARE v_estado_nuevo VARCHAR(25);
    DECLARE v_id_mecanico_orden INT UNSIGNED DEFAULT NULL;
    DECLARE v_inventario_descontado TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_observacion VARCHAR(500);
    DECLARE v_transicion_valida TINYINT UNSIGNED DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_historial_estado_creado = NULL;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_id_historial_estado_creado = NULL;
    SET v_estado_nuevo = LOWER(TRIM(p_estado_nuevo));
    SET v_observacion = NULLIF(TRIM(p_observacion), '');

    IF p_id_usuario_actor IS NULL OR p_id_orden_trabajo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor y la orden son obligatorios';
    END IF;

    IF v_estado_nuevo IS NULL OR v_estado_nuevo = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El estado nuevo es obligatorio';
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

    IF v_rol_actor = 'mecanico' AND v_id_mecanico_actor IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor mecanico no tiene un perfil activo';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_cambiar_estado_orden';
    SET @app_motivo = v_observacion;

    START TRANSACTION;

    -- El bloqueo impide transiciones concurrentes sobre la misma orden.
    SELECT ot.estado, ot.id_mecanico, ot.inventario_descontado
      INTO v_estado_actual, v_id_mecanico_orden, v_inventario_descontado
      FROM orden_trabajo AS ot
     WHERE ot.id_orden_trabajo = p_id_orden_trabajo
     FOR UPDATE;

    IF v_estado_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden de trabajo no existe';
    END IF;

    IF v_rol_actor = 'mecanico'
       AND v_id_mecanico_actor <> v_id_mecanico_orden THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El mecanico actor no es responsable de la orden';
    END IF;

    IF v_estado_actual IN ('finalizada', 'cancelada') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar una orden en estado terminal';
    END IF;

    IF v_estado_nuevo = v_estado_actual THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El estado nuevo debe ser diferente del actual';
    END IF;

    IF v_estado_nuevo = 'finalizada' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Use sp_finalizar_orden para finalizar una orden';
    END IF;

    SET v_transicion_valida = CASE
        WHEN v_estado_actual = 'ingresada'
             AND v_estado_nuevo IN ('diagnostico', 'cancelada') THEN 1
        WHEN v_estado_actual = 'diagnostico'
             AND v_estado_nuevo IN (
                 'esperando_repuestos',
                 'en_reparacion',
                 'cancelada'
             ) THEN 1
        WHEN v_estado_actual = 'esperando_repuestos'
             AND v_estado_nuevo IN ('en_reparacion', 'cancelada') THEN 1
        WHEN v_estado_actual = 'en_reparacion'
             AND v_estado_nuevo IN ('esperando_repuestos', 'cancelada') THEN 1
        ELSE 0
    END;

    IF v_transicion_valida = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La transicion de estado no esta permitida';
    END IF;

    IF v_inventario_descontado <> 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden ya tiene inventario descontado';
    END IF;

    UPDATE orden_trabajo AS ot
       SET estado = v_estado_nuevo
     WHERE ot.id_orden_trabajo = p_id_orden_trabajo;

    INSERT INTO historial_estado_orden (
        id_orden_trabajo,
        estado_anterior,
        estado_nuevo,
        id_usuario,
        observacion
    )
    VALUES (
        p_id_orden_trabajo,
        v_estado_actual,
        v_estado_nuevo,
        p_id_usuario_actor,
        v_observacion
    );

    SET p_id_historial_estado_creado = LAST_INSERT_ID();

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Finaliza una orden y descuenta los repuestos agrupados en una transacción.
DROP PROCEDURE IF EXISTS sp_finalizar_orden$$
CREATE PROCEDURE sp_finalizar_orden (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_id_orden_trabajo INT UNSIGNED,
    IN p_observacion VARCHAR(500),
    OUT p_id_historial_estado_creado INT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_rol_actor VARCHAR(30) DEFAULT NULL;
    DECLARE v_id_mecanico_actor INT UNSIGNED DEFAULT NULL;
    DECLARE v_estado_orden VARCHAR(25) DEFAULT NULL;
    DECLARE v_id_mecanico_orden INT UNSIGNED DEFAULT NULL;
    DECLARE v_diagnostico TEXT;
    DECLARE v_inventario_descontado TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_cantidad_detalles INT DEFAULT 0;
    DECLARE v_observacion VARCHAR(500);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_historial_estado_creado = NULL;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_id_historial_estado_creado = NULL;
    SET v_observacion = NULLIF(TRIM(p_observacion), '');

    IF p_id_usuario_actor IS NULL OR p_id_orden_trabajo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor y la orden son obligatorios';
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

    IF v_rol_actor = 'mecanico' AND v_id_mecanico_actor IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor mecanico no tiene un perfil activo';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_finalizar_orden';
    SET @app_motivo = v_observacion;

    START TRANSACTION;

    -- La orden se bloquea primero, igual que al agregar un detalle.
    SELECT ot.estado,
           ot.id_mecanico,
           ot.diagnostico,
           ot.inventario_descontado
      INTO v_estado_orden,
           v_id_mecanico_orden,
           v_diagnostico,
           v_inventario_descontado
      FROM orden_trabajo AS ot
     WHERE ot.id_orden_trabajo = p_id_orden_trabajo
     FOR UPDATE;

    IF v_estado_orden IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden de trabajo no existe';
    END IF;

    IF v_rol_actor = 'mecanico'
       AND v_id_mecanico_actor <> v_id_mecanico_orden THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El mecanico actor no es responsable de la orden';
    END IF;

    IF v_estado_orden <> 'en_reparacion' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo puede finalizar una orden en reparacion';
    END IF;

    IF v_diagnostico IS NULL OR TRIM(v_diagnostico) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden debe tener un diagnostico';
    END IF;

    IF v_inventario_descontado <> 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El inventario de la orden ya fue descontado';
    END IF;

    SELECT COUNT(*)
      INTO v_cantidad_detalles
      FROM detalle_orden AS det
     WHERE det.id_orden_trabajo = p_id_orden_trabajo;

    IF v_cantidad_detalles = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden debe contener al menos un detalle';
    END IF;

    -- El handler NOT FOUND queda aislado del resto de SELECT ... INTO.
    BEGIN
        DECLARE v_fin_cursor TINYINT UNSIGNED DEFAULT 0;
        DECLARE v_id_repuesto INT UNSIGNED DEFAULT NULL;
        DECLARE v_cantidad_requerida DECIMAL(12,2) DEFAULT NULL;
        DECLARE v_stock_actual DECIMAL(12,2) DEFAULT NULL;

        DECLARE cur_repuestos CURSOR FOR
            SELECT det.id_repuesto, SUM(det.cantidad)
              FROM detalle_orden AS det
             WHERE det.id_orden_trabajo = p_id_orden_trabajo
               AND det.id_repuesto IS NOT NULL
             GROUP BY det.id_repuesto
             ORDER BY det.id_repuesto;

        DECLARE CONTINUE HANDLER FOR NOT FOUND
            SET v_fin_cursor = 1;

        OPEN cur_repuestos;

        bucle_repuestos: LOOP
            FETCH cur_repuestos
             INTO v_id_repuesto, v_cantidad_requerida;

            IF v_fin_cursor = 1 THEN
                LEAVE bucle_repuestos;
            END IF;

            SET v_stock_actual = NULL;

            -- Los repuestos se bloquean en orden ascendente de identificador.
            SELECT r.stock_actual
              INTO v_stock_actual
              FROM repuesto AS r
             WHERE r.id_repuesto = v_id_repuesto
             FOR UPDATE;

            IF v_stock_actual IS NULL THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Un repuesto de la orden ya no existe';
            END IF;

            IF v_stock_actual < v_cantidad_requerida THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Stock insuficiente para finalizar la orden';
            END IF;

            UPDATE repuesto AS r
               SET stock_actual = stock_actual - v_cantidad_requerida
             WHERE r.id_repuesto = v_id_repuesto;
        END LOOP;

        CLOSE cur_repuestos;
    END;

    UPDATE orden_trabajo AS ot
       SET estado = 'finalizada',
           inventario_descontado = 1,
           fecha_finalizacion = CURRENT_TIMESTAMP
     WHERE ot.id_orden_trabajo = p_id_orden_trabajo;

    INSERT INTO historial_estado_orden (
        id_orden_trabajo,
        estado_anterior,
        estado_nuevo,
        id_usuario,
        observacion
    )
    VALUES (
        p_id_orden_trabajo,
        'en_reparacion',
        'finalizada',
        p_id_usuario_actor,
        v_observacion
    );

    SET p_id_historial_estado_creado = LAST_INSERT_ID();

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Genera una factura y copia los detalles congelados de una orden finalizada.
DROP PROCEDURE IF EXISTS sp_generar_factura$$
CREATE PROCEDURE sp_generar_factura (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_id_orden_trabajo INT UNSIGNED,
    OUT p_id_factura_creada INT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_estado_orden VARCHAR(25) DEFAULT NULL;
    DECLARE v_inventario_descontado TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_id_vehiculo INT UNSIGNED DEFAULT NULL;
    DECLARE v_id_cliente INT UNSIGNED DEFAULT NULL;
    DECLARE v_placa_vehiculo VARCHAR(10) DEFAULT NULL;
    DECLARE v_identificacion_cliente VARCHAR(13) DEFAULT NULL;
    DECLARE v_nombre_cliente VARCHAR(200) DEFAULT NULL;
    DECLARE v_direccion_cliente VARCHAR(255) DEFAULT NULL;
    DECLARE v_cantidad_detalles INT DEFAULT 0;
    DECLARE v_detalles_insertados INT DEFAULT 0;
    DECLARE v_facturas_existentes INT DEFAULT 0;
    DECLARE v_subtotal DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_porcentaje_iva DECIMAL(5,2) DEFAULT 15.00;
    DECLARE v_valor_iva DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_total DECIMAL(12,2) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_factura_creada = NULL;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_id_factura_creada = NULL;

    IF p_id_usuario_actor IS NULL OR p_id_orden_trabajo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor y la orden son obligatorios';
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
            SET MESSAGE_TEXT = 'El actor no existe, esta inactivo o no tiene rol permitido';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_generar_factura';
    SET @app_motivo = NULL;

    START TRANSACTION;

    -- La orden se bloquea primero para serializar la facturación.
    SELECT ot.estado, ot.inventario_descontado, ot.id_vehiculo
      INTO v_estado_orden, v_inventario_descontado, v_id_vehiculo
      FROM orden_trabajo AS ot
     WHERE ot.id_orden_trabajo = p_id_orden_trabajo
     FOR UPDATE;

    IF v_estado_orden IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden de trabajo no existe';
    END IF;

    IF v_estado_orden <> 'finalizada' OR v_inventario_descontado <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden debe estar finalizada y con inventario descontado';
    END IF;

    SELECT COUNT(*)
      INTO v_facturas_existentes
      FROM factura AS f
     WHERE f.id_orden_trabajo = p_id_orden_trabajo;

    IF v_facturas_existentes > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden ya tiene una factura';
    END IF;

    -- Vehículo y cliente se bloquean después de la orden para una instantánea consistente.
    SELECT v.id_cliente, v.placa
      INTO v_id_cliente, v_placa_vehiculo
      FROM vehiculo AS v
     WHERE v.id_vehiculo = v_id_vehiculo
     FOR UPDATE;

    IF v_id_cliente IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El vehiculo historico de la orden no existe';
    END IF;

    SELECT c.identificacion,
           CASE
               WHEN c.tipo_cliente = 'persona'
                   THEN CONCAT_WS(' ', NULLIF(TRIM(c.nombres), ''), NULLIF(TRIM(c.apellidos), ''))
               WHEN c.tipo_cliente = 'empresa'
                   THEN c.razon_social
               ELSE NULL
           END,
           c.direccion
      INTO v_identificacion_cliente, v_nombre_cliente, v_direccion_cliente
      FROM cliente AS c
     WHERE c.id_cliente = v_id_cliente
     FOR UPDATE;

    SET v_identificacion_cliente = NULLIF(TRIM(v_identificacion_cliente), '');
    SET v_nombre_cliente = NULLIF(TRIM(v_nombre_cliente), '');
    SET v_placa_vehiculo = NULLIF(TRIM(v_placa_vehiculo), '');

    IF v_identificacion_cliente IS NULL
       OR v_nombre_cliente IS NULL
       OR v_placa_vehiculo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La instantanea de cliente y vehiculo esta incompleta';
    END IF;

    SELECT COUNT(*), SUM(det.subtotal)
      INTO v_cantidad_detalles, v_subtotal
      FROM detalle_orden AS det
     WHERE det.id_orden_trabajo = p_id_orden_trabajo;

    IF v_cantidad_detalles = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La orden debe contener al menos un detalle';
    END IF;

    IF v_subtotal IS NULL OR v_subtotal < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El subtotal calculado de la orden no es valido';
    END IF;

    SET v_valor_iva = ROUND(v_subtotal * v_porcentaje_iva / 100, 2);
    SET v_total = v_subtotal + v_valor_iva;

    INSERT INTO factura (
        id_orden_trabajo,
        estado,
        fecha_emision,
        identificacion_cliente,
        nombre_cliente,
        direccion_cliente,
        placa_vehiculo,
        subtotal,
        porcentaje_iva,
        valor_iva,
        total,
        id_usuario_emision,
        fecha_anulacion,
        id_usuario_anulacion,
        motivo_anulacion
    )
    VALUES (
        p_id_orden_trabajo,
        'emitida',
        CURRENT_TIMESTAMP,
        v_identificacion_cliente,
        v_nombre_cliente,
        v_direccion_cliente,
        v_placa_vehiculo,
        v_subtotal,
        v_porcentaje_iva,
        v_valor_iva,
        v_total,
        p_id_usuario_actor,
        NULL,
        NULL,
        NULL
    );

    SET p_id_factura_creada = LAST_INSERT_ID();

    -- Se copian exclusivamente los importes congelados de detalle_orden.
    INSERT INTO detalle_factura (
        id_factura,
        id_detalle_orden,
        tipo_concepto,
        codigo_concepto,
        descripcion_concepto,
        cantidad,
        precio_unitario,
        subtotal
    )
    SELECT p_id_factura_creada,
           det.id_detalle_orden,
           CASE
               WHEN det.id_servicio IS NOT NULL THEN 'servicio'
               ELSE 'repuesto'
           END,
           CASE
               WHEN det.id_servicio IS NOT NULL THEN s.codigo
               ELSE r.codigo
           END,
           det.descripcion_concepto,
           det.cantidad,
           det.precio_unitario,
           det.subtotal
      FROM detalle_orden AS det
      LEFT JOIN servicio AS s ON s.id_servicio = det.id_servicio
      LEFT JOIN repuesto AS r ON r.id_repuesto = det.id_repuesto
     WHERE det.id_orden_trabajo = p_id_orden_trabajo;

    SET v_detalles_insertados = ROW_COUNT();

    IF v_detalles_insertados <> v_cantidad_detalles THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se copiaron todos los detalles de la orden';
    END IF;

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Registra el pago total de una factura emitida.
DROP PROCEDURE IF EXISTS sp_registrar_pago$$
CREATE PROCEDURE sp_registrar_pago (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_id_factura INT UNSIGNED,
    IN p_monto DECIMAL(12,2),
    IN p_metodo_pago VARCHAR(20),
    IN p_referencia VARCHAR(100),
    IN p_fecha_pago DATETIME,
    OUT p_id_pago_creado INT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_metodo_pago VARCHAR(20) DEFAULT NULL;
    DECLARE v_referencia VARCHAR(100) DEFAULT NULL;
    DECLARE v_fecha_pago DATETIME DEFAULT NULL;
    DECLARE v_estado_factura VARCHAR(10) DEFAULT NULL;
    DECLARE v_fecha_emision DATETIME DEFAULT NULL;
    DECLARE v_total_factura DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_pagos_registrados INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_pago_creado = NULL;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_id_pago_creado = NULL;
    SET v_metodo_pago = LOWER(TRIM(p_metodo_pago));
    SET v_referencia = NULLIF(TRIM(p_referencia), '');
    SET v_fecha_pago = COALESCE(p_fecha_pago, CURRENT_TIMESTAMP);

    IF p_id_usuario_actor IS NULL OR p_id_factura IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor y la factura son obligatorios';
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El monto debe ser mayor que cero';
    END IF;

    IF v_metodo_pago IS NULL
       OR v_metodo_pago NOT IN ('efectivo', 'tarjeta', 'transferencia') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El metodo de pago no es valido';
    END IF;

    IF v_metodo_pago IN ('tarjeta', 'transferencia')
       AND v_referencia IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La referencia es obligatoria para este metodo de pago';
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
            SET MESSAGE_TEXT = 'El actor no existe, esta inactivo o no tiene rol permitido';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_registrar_pago';
    SET @app_motivo = NULL;

    START TRANSACTION;

    -- El bloqueo de factura serializa intentos simultáneos de pago.
    SELECT f.estado, f.fecha_emision, f.total
      INTO v_estado_factura, v_fecha_emision, v_total_factura
      FROM factura AS f
     WHERE f.id_factura = p_id_factura
     FOR UPDATE;

    IF v_estado_factura IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La factura no existe';
    END IF;

    IF v_estado_factura <> 'emitida' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo se puede pagar una factura emitida';
    END IF;

    IF p_monto <> v_total_factura THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pago debe ser exactamente igual al total de la factura';
    END IF;

    IF v_fecha_pago < v_fecha_emision THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La fecha de pago no puede ser anterior a la emision';
    END IF;

    SELECT COUNT(*)
      INTO v_pagos_registrados
      FROM pago AS p
     WHERE p.id_factura = p_id_factura
       AND p.estado = 'registrado';

    IF v_pagos_registrados > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La factura ya tiene un pago registrado';
    END IF;

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
        p_id_factura,
        p_monto,
        v_metodo_pago,
        v_referencia,
        'registrado',
        v_fecha_pago,
        p_id_usuario_actor,
        NULL,
        NULL,
        NULL
    );

    SET p_id_pago_creado = LAST_INSERT_ID();

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Anula un pago sin eliminar su registro histórico.
DROP PROCEDURE IF EXISTS sp_anular_pago$$
CREATE PROCEDURE sp_anular_pago (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_id_pago INT UNSIGNED,
    IN p_motivo_anulacion VARCHAR(500),
    OUT p_pago_anulado TINYINT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_motivo_anulacion VARCHAR(500) DEFAULT NULL;
    DECLARE v_id_factura_esperada INT UNSIGNED DEFAULT NULL;
    DECLARE v_id_factura_pago INT UNSIGNED DEFAULT NULL;
    DECLARE v_estado_factura VARCHAR(10) DEFAULT NULL;
    DECLARE v_estado_pago VARCHAR(10) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_pago_anulado = 0;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_pago_anulado = 0;
    SET v_motivo_anulacion = NULLIF(TRIM(p_motivo_anulacion), '');

    IF p_id_usuario_actor IS NULL OR p_id_pago IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor y el pago son obligatorios';
    END IF;

    IF v_motivo_anulacion IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El motivo de anulacion es obligatorio';
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
            SET MESSAGE_TEXT = 'El actor debe ser un administrador activo';
    END IF;

    -- La lectura inicial permite conocer qué factura debe bloquearse primero.
    SELECT p.id_factura
      INTO v_id_factura_esperada
      FROM pago AS p
     WHERE p.id_pago = p_id_pago;

    IF v_id_factura_esperada IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pago no existe';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_anular_pago';
    SET @app_motivo = v_motivo_anulacion;

    START TRANSACTION;

    -- Se bloquea siempre factura antes que pago para reducir deadlocks.
    SELECT f.estado
      INTO v_estado_factura
      FROM factura AS f
     WHERE f.id_factura = v_id_factura_esperada
     FOR UPDATE;

    IF v_estado_factura IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La factura asociada al pago no existe';
    END IF;

    SELECT p.id_factura, p.estado
      INTO v_id_factura_pago, v_estado_pago
      FROM pago AS p
     WHERE p.id_pago = p_id_pago
     FOR UPDATE;

    IF v_id_factura_pago IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pago ya no existe';
    END IF;

    IF v_id_factura_pago <> v_id_factura_esperada THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pago cambio de factura durante la operacion';
    END IF;

    IF v_estado_factura <> 'emitida' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede anular un pago de una factura anulada';
    END IF;

    IF v_estado_pago <> 'registrado' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El pago ya esta anulado';
    END IF;

    UPDATE pago AS p
       SET estado = 'anulado',
           fecha_anulacion = CURRENT_TIMESTAMP,
           id_usuario_anulacion = p_id_usuario_actor,
           motivo_anulacion = v_motivo_anulacion
     WHERE p.id_pago = p_id_pago;

    SET p_pago_anulado = 1;

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

-- Anula una factura emitida cuando no conserva pagos registrados.
DROP PROCEDURE IF EXISTS sp_anular_factura$$
CREATE PROCEDURE sp_anular_factura (
    IN p_id_usuario_actor INT UNSIGNED,
    IN p_id_factura INT UNSIGNED,
    IN p_motivo_anulacion VARCHAR(500),
    OUT p_factura_anulada TINYINT UNSIGNED
)
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_valido INT DEFAULT 0;
    DECLARE v_motivo_anulacion VARCHAR(500) DEFAULT NULL;
    DECLARE v_estado_factura VARCHAR(10) DEFAULT NULL;
    DECLARE v_pagos_registrados INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_factura_anulada = 0;
        SET @app_id_usuario = NULL;
        SET @app_origen = NULL;
        SET @app_motivo = NULL;
        RESIGNAL;
    END;

    SET p_factura_anulada = 0;
    SET v_motivo_anulacion = NULLIF(TRIM(p_motivo_anulacion), '');

    IF p_id_usuario_actor IS NULL OR p_id_factura IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El actor y la factura son obligatorios';
    END IF;

    IF v_motivo_anulacion IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El motivo de anulacion es obligatorio';
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
            SET MESSAGE_TEXT = 'El actor debe ser un administrador activo';
    END IF;

    SET @app_id_usuario = p_id_usuario_actor;
    SET @app_origen = 'sp_anular_factura';
    SET @app_motivo = v_motivo_anulacion;

    START TRANSACTION;

    -- El bloqueo impide competir con el registro o la anulación de pagos.
    SELECT f.estado
      INTO v_estado_factura
      FROM factura AS f
     WHERE f.id_factura = p_id_factura
     FOR UPDATE;

    IF v_estado_factura IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La factura no existe';
    END IF;

    IF v_estado_factura <> 'emitida' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La factura ya esta anulada';
    END IF;

    SELECT COUNT(*)
      INTO v_pagos_registrados
      FROM pago AS p
     WHERE p.id_factura = p_id_factura
       AND p.estado = 'registrado';

    IF v_pagos_registrados > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Primero debe anularse el pago registrado';
    END IF;

    UPDATE factura AS f
       SET estado = 'anulada',
           fecha_anulacion = CURRENT_TIMESTAMP,
           id_usuario_anulacion = p_id_usuario_actor,
           motivo_anulacion = v_motivo_anulacion
     WHERE f.id_factura = p_id_factura;

    SET p_factura_anulada = 1;

    COMMIT;

    SET @app_id_usuario = NULL;
    SET @app_origen = NULL;
    SET @app_motivo = NULL;
END$$

DELIMITER ;
