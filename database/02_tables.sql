-- Fase 1A: creación estructural de las tablas.
-- Las relaciones y demás restricciones se incorporarán en fases posteriores.

USE taller_mecanico;

-- 1. Catálogo de roles de la aplicación.
CREATE TABLE rol (
    id_rol INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(30) NOT NULL,
    descripcion VARCHAR(255) NULL DEFAULT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_rol PRIMARY KEY (id_rol)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Catálogo de roles de la aplicación';

-- 2. Cuentas de usuario de la aplicación.
CREATE TABLE usuario (
    id_usuario INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_rol INT UNSIGNED NOT NULL,
    cedula VARCHAR(10) NOT NULL,
    nombre_usuario VARCHAR(60) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    correo VARCHAR(254) NOT NULL,
    telefono VARCHAR(20) NULL DEFAULT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    fecha_desactivacion DATETIME NULL DEFAULT NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Cuentas de usuario de la aplicación';

-- 3. Perfiles técnicos de mecánicos.
CREATE TABLE mecanico (
    id_mecanico INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_usuario INT UNSIGNED NOT NULL,
    especialidad VARCHAR(100) NOT NULL,
    nivel VARCHAR(20) NOT NULL,
    maximo_ordenes_activas TINYINT UNSIGNED NOT NULL DEFAULT 3,
    disponibilidad VARCHAR(20) NOT NULL DEFAULT 'disponible',
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_mecanico PRIMARY KEY (id_mecanico)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Perfiles técnicos de los usuarios mecánicos';

-- 4. Clientes personas naturales o empresas.
CREATE TABLE cliente (
    id_cliente INT UNSIGNED NOT NULL AUTO_INCREMENT,
    tipo_cliente VARCHAR(10) NOT NULL,
    tipo_identificacion VARCHAR(10) NOT NULL,
    identificacion VARCHAR(13) NOT NULL,
    nombres VARCHAR(100) NULL DEFAULT NULL,
    apellidos VARCHAR(100) NULL DEFAULT NULL,
    razon_social VARCHAR(150) NULL DEFAULT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo VARCHAR(254) NULL DEFAULT NULL,
    direccion VARCHAR(255) NULL DEFAULT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    fecha_desactivacion DATETIME NULL DEFAULT NULL,
    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Clientes propietarios de vehículos';

-- 5. Vehículos atendidos por el taller.
CREATE TABLE vehiculo (
    id_vehiculo INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_cliente INT UNSIGNED NOT NULL,
    placa VARCHAR(10) NOT NULL,
    numero_chasis VARCHAR(50) NULL DEFAULT NULL,
    marca VARCHAR(60) NOT NULL,
    modelo VARCHAR(60) NOT NULL,
    anio SMALLINT UNSIGNED NULL DEFAULT NULL,
    color VARCHAR(40) NULL DEFAULT NULL,
    kilometraje_actual INT UNSIGNED NOT NULL DEFAULT 0,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    fecha_desactivacion DATETIME NULL DEFAULT NULL,
    CONSTRAINT pk_vehiculo PRIMARY KEY (id_vehiculo)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Vehículos asociados a clientes';

-- 6. Catálogo de servicios y mano de obra.
CREATE TABLE servicio (
    id_servicio INT UNSIGNED NOT NULL AUTO_INCREMENT,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    categoria VARCHAR(60) NULL DEFAULT NULL,
    duracion_estimada_minutos SMALLINT UNSIGNED NULL DEFAULT NULL,
    descripcion TEXT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_servicio PRIMARY KEY (id_servicio)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Catálogo de servicios y mano de obra';

-- 7. Catálogo e inventario actual de repuestos.
CREATE TABLE repuesto (
    id_repuesto INT UNSIGNED NOT NULL AUTO_INCREMENT,
    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    marca VARCHAR(80) NULL DEFAULT NULL,
    descripcion TEXT NULL,
    stock_actual DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    stock_minimo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    unidad_medida VARCHAR(20) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_repuesto PRIMARY KEY (id_repuesto)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Catálogo e inventario actual de repuestos';

-- 8. Historial de costos y precios de venta.
CREATE TABLE historial_precio (
    id_historial_precio INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_servicio INT UNSIGNED NULL DEFAULT NULL,
    id_repuesto INT UNSIGNED NULL DEFAULT NULL,
    costo_base DECIMAL(12,2) NOT NULL,
    precio_venta DECIMAL(12,2) NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NULL DEFAULT NULL,
    id_usuario_creador INT UNSIGNED NOT NULL,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_historial_precio PRIMARY KEY (id_historial_precio)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Historial de costos y precios de servicios y repuestos';

-- 9. Cabeceras de órdenes de trabajo.
CREATE TABLE orden_trabajo (
    id_orden_trabajo INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_vehiculo INT UNSIGNED NOT NULL,
    id_mecanico INT UNSIGNED NOT NULL,
    id_usuario_apertura INT UNSIGNED NOT NULL,
    estado VARCHAR(25) NOT NULL DEFAULT 'ingresada',
    descripcion_problema TEXT NOT NULL,
    diagnostico TEXT NULL,
    observacion TEXT NULL,
    kilometraje_ingreso INT UNSIGNED NOT NULL,
    inventario_descontado TINYINT(1) NOT NULL DEFAULT 0,
    fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_finalizacion DATETIME NULL DEFAULT NULL,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_orden_trabajo PRIMARY KEY (id_orden_trabajo)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Cabeceras y estado actual de órdenes de trabajo';

-- 10. Historial de transiciones de las órdenes.
CREATE TABLE historial_estado_orden (
    id_historial_estado_orden INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_orden_trabajo INT UNSIGNED NOT NULL,
    estado_anterior VARCHAR(25) NULL DEFAULT NULL,
    estado_nuevo VARCHAR(25) NOT NULL,
    id_usuario INT UNSIGNED NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion VARCHAR(500) NULL DEFAULT NULL,
    CONSTRAINT pk_historial_estado_orden
        PRIMARY KEY (id_historial_estado_orden)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Historial inmutable de estados de las órdenes';

-- 11. Conceptos cobrables de las órdenes.
CREATE TABLE detalle_orden (
    id_detalle_orden INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_orden_trabajo INT UNSIGNED NOT NULL,
    id_servicio INT UNSIGNED NULL DEFAULT NULL,
    id_repuesto INT UNSIGNED NULL DEFAULT NULL,
    id_historial_precio INT UNSIGNED NOT NULL,
    descripcion_concepto VARCHAR(255) NOT NULL,
    cantidad DECIMAL(12,2) NOT NULL,
    precio_unitario DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    observacion VARCHAR(500) NULL DEFAULT NULL,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_detalle_orden PRIMARY KEY (id_detalle_orden)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Conceptos cobrables y precios congelados de las órdenes';

-- 12. Cabeceras de facturas emitidas.
CREATE TABLE factura (
    id_factura INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_orden_trabajo INT UNSIGNED NOT NULL,
    estado VARCHAR(10) NOT NULL DEFAULT 'emitida',
    fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    identificacion_cliente VARCHAR(13) NOT NULL,
    nombre_cliente VARCHAR(200) NOT NULL,
    direccion_cliente VARCHAR(255) NULL DEFAULT NULL,
    placa_vehiculo VARCHAR(10) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    porcentaje_iva DECIMAL(5,2) NOT NULL DEFAULT 15.00,
    valor_iva DECIMAL(12,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    id_usuario_emision INT UNSIGNED NOT NULL,
    fecha_anulacion DATETIME NULL DEFAULT NULL,
    id_usuario_anulacion INT UNSIGNED NULL DEFAULT NULL,
    motivo_anulacion VARCHAR(500) NULL DEFAULT NULL,
    CONSTRAINT pk_factura PRIMARY KEY (id_factura)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Facturas generadas desde órdenes finalizadas';

-- 13. Instantáneas de conceptos facturados.
CREATE TABLE detalle_factura (
    id_detalle_factura INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_factura INT UNSIGNED NOT NULL,
    id_detalle_orden INT UNSIGNED NOT NULL,
    tipo_concepto VARCHAR(10) NOT NULL,
    codigo_concepto VARCHAR(40) NOT NULL,
    descripcion_concepto VARCHAR(255) NOT NULL,
    cantidad DECIMAL(12,2) NOT NULL,
    precio_unitario DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    CONSTRAINT pk_detalle_factura PRIMARY KEY (id_detalle_factura)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Instantáneas de los conceptos facturados';

-- 14. Pagos totales y sus anulaciones.
CREATE TABLE pago (
    id_pago INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_factura INT UNSIGNED NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    metodo_pago VARCHAR(20) NOT NULL,
    referencia VARCHAR(100) NULL DEFAULT NULL,
    estado VARCHAR(10) NOT NULL DEFAULT 'registrado',
    fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_registro INT UNSIGNED NOT NULL,
    fecha_anulacion DATETIME NULL DEFAULT NULL,
    id_usuario_anulacion INT UNSIGNED NULL DEFAULT NULL,
    motivo_anulacion VARCHAR(500) NULL DEFAULT NULL,
    CONSTRAINT pk_pago PRIMARY KEY (id_pago)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Pagos totales registrados para las facturas';

-- 15. Registro transversal de auditoría.
CREATE TABLE auditoria (
    id_auditoria BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_usuario INT UNSIGNED NULL DEFAULT NULL,
    tabla_afectada VARCHAR(64) NOT NULL,
    id_registro BIGINT UNSIGNED NOT NULL,
    accion VARCHAR(30) NOT NULL,
    motivo VARCHAR(500) NULL DEFAULT NULL,
    datos_anteriores JSON NULL DEFAULT NULL,
    datos_nuevos JSON NULL DEFAULT NULL,
    fecha_evento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    origen VARCHAR(50) NULL DEFAULT NULL,
    direccion_ip VARCHAR(45) NULL DEFAULT NULL,
    CONSTRAINT pk_auditoria PRIMARY KEY (id_auditoria)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci
  COMMENT = 'Registro transversal de operaciones sensibles';
