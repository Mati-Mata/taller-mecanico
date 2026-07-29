-- Datos semilla reproducibles para demostrar el flujo integral del taller.
-- Este script requiere una base recién creada y vacía.
-- Para ejecutarlo nuevamente, reconstruya la base desde 01_create_database.sql.

USE taller_mecanico;

SET @app_id_usuario = NULL;
SET @app_origen = NULL;
SET @app_motivo = NULL;

-- ---------------------------------------------------------------------------
-- Roles y usuarios
-- ---------------------------------------------------------------------------

INSERT INTO rol (nombre, descripcion, activo)
VALUES
    ('administrador', 'Administración integral del taller', 1),
    ('asesor', 'Atención, órdenes, facturación y pagos', 1),
    ('mecanico', 'Diagnóstico y reparación de vehículos', 1);

SELECT id_rol INTO @id_rol_administrador
  FROM rol
 WHERE nombre = 'administrador';

SELECT id_rol INTO @id_rol_asesor
  FROM rol
 WHERE nombre = 'asesor';

SELECT id_rol INTO @id_rol_mecanico
  FROM rol
 WHERE nombre = 'mecanico';

-- Hashes ficticios de demostración: el backend deberá reemplazarlos por
-- hashes bcrypt o Argon2 reales antes de cualquier uso fuera de la demo.
INSERT INTO usuario (
    id_rol,
    cedula,
    nombre_usuario,
    password_hash,
    nombres,
    apellidos,
    correo,
    telefono,
    activo,
    fecha_desactivacion
)
VALUES (
    @id_rol_administrador,
    '1712345678',
    'admin_demo',
    'DEMO_HASH_NO_USAR_ADMIN_2026',
    'Andrea',
    'Montalvo',
    'andrea.montalvo@example.com',
    '0990000001',
    1,
    NULL
);

SELECT id_usuario INTO @id_usuario_administrador
  FROM usuario
 WHERE nombre_usuario = 'admin_demo';

SET @app_id_usuario = @id_usuario_administrador;
SET @app_origen = '08_seed_data';
SET @app_motivo = 'Carga inicial de datos';

INSERT INTO usuario (
    id_rol,
    cedula,
    nombre_usuario,
    password_hash,
    nombres,
    apellidos,
    correo,
    telefono,
    activo,
    fecha_desactivacion
)
VALUES
    (
        @id_rol_asesor,
        '1723456789',
        'asesor_demo',
        'DEMO_HASH_NO_USAR_ASESOR_2026',
        'Bruno',
        'Salazar',
        'bruno.salazar@example.com',
        '0990000002',
        1,
        NULL
    ),
    (
        @id_rol_mecanico,
        '1734567890',
        'mecanico_uno',
        'DEMO_HASH_NO_USAR_MECANICO_1_2026',
        'Carlos',
        'Paredes',
        'carlos.paredes@example.com',
        '0990000003',
        1,
        NULL
    ),
    (
        @id_rol_mecanico,
        '1745678901',
        'mecanico_dos',
        'DEMO_HASH_NO_USAR_MECANICO_2_2026',
        'Diana',
        'Villacís',
        'diana.villacis@example.com',
        '0990000004',
        1,
        NULL
    );

SELECT id_usuario INTO @id_usuario_asesor
  FROM usuario
 WHERE nombre_usuario = 'asesor_demo';

SELECT id_usuario INTO @id_usuario_mecanico_1
  FROM usuario
 WHERE nombre_usuario = 'mecanico_uno';

SELECT id_usuario INTO @id_usuario_mecanico_2
  FROM usuario
 WHERE nombre_usuario = 'mecanico_dos';

INSERT INTO mecanico (
    id_usuario,
    especialidad,
    nivel,
    maximo_ordenes_activas,
    disponibilidad,
    activo
)
VALUES
    (
        @id_usuario_mecanico_1,
        'Motor y mantenimiento preventivo',
        'senior',
        4,
        'disponible',
        1
    ),
    (
        @id_usuario_mecanico_2,
        'Frenos, suspensión y alineación',
        'intermedio',
        4,
        'disponible',
        1
    );

SELECT id_mecanico INTO @id_mecanico_1
  FROM mecanico
 WHERE id_usuario = @id_usuario_mecanico_1;

SELECT id_mecanico INTO @id_mecanico_2
  FROM mecanico
 WHERE id_usuario = @id_usuario_mecanico_2;

-- ---------------------------------------------------------------------------
-- Catálogos de servicios y repuestos
-- ---------------------------------------------------------------------------

INSERT INTO servicio (
    codigo,
    nombre,
    categoria,
    duracion_estimada_minutos,
    descripcion,
    activo
)
VALUES
    (
        'SER-DIAG',
        'Diagnóstico general',
        'diagnostico',
        60,
        'Inspección general y lectura inicial de fallas',
        1
    ),
    (
        'SER-ACEI',
        'Cambio de aceite',
        'mantenimiento',
        45,
        'Cambio de aceite de motor y revisión de niveles',
        1
    ),
    (
        'SER-FREN',
        'Mantenimiento de frenos',
        'frenos',
        120,
        'Inspección y mantenimiento del sistema de frenos',
        1
    ),
    (
        'SER-ALIN',
        'Alineación',
        'suspension',
        60,
        'Alineación de dirección y comprobación de geometría',
        1
    ),
    (
        'SER-ELEC',
        'Revisión eléctrica',
        'electricidad',
        90,
        'Diagnóstico del sistema eléctrico del vehículo',
        1
    );

INSERT INTO repuesto (
    codigo,
    nombre,
    marca,
    descripcion,
    stock_actual,
    stock_minimo,
    unidad_medida,
    activo
)
VALUES
    (
        'REP-FILT-ACE',
        'Filtro de aceite',
        'DemoParts',
        'Filtro compatible con motores de demostración',
        30.00,
        5.00,
        'unidad',
        1
    ),
    (
        'REP-ACE-5W30',
        'Aceite de motor 5W30',
        'DemoOil',
        'Aceite sintético para motor',
        100.00,
        20.00,
        'litro',
        1
    ),
    (
        'REP-PAST-FRE',
        'Pastillas de freno',
        'DemoBrake',
        'Juego de pastillas de freno delanteras',
        24.00,
        4.00,
        'juego',
        1
    ),
    (
        'REP-BOMB-12V',
        'Bombillo 12V',
        'DemoLight',
        'Bombillo automotriz de propósito general',
        40.00,
        8.00,
        'unidad',
        1
    ),
    (
        'REP-CORREA',
        'Correa de accesorios',
        'DemoBelt',
        'Correa multipropósito de demostración',
        18.00,
        3.00,
        'unidad',
        1
    ),
    (
        'REP-LIQ-FRE',
        'Líquido de frenos',
        'DemoFluid',
        'Líquido para sistema hidráulico de frenos',
        50.00,
        10.00,
        'litro',
        1
    );

SELECT id_servicio INTO @id_servicio_diagnostico
  FROM servicio WHERE codigo = 'SER-DIAG';
SELECT id_servicio INTO @id_servicio_aceite
  FROM servicio WHERE codigo = 'SER-ACEI';
SELECT id_servicio INTO @id_servicio_frenos
  FROM servicio WHERE codigo = 'SER-FREN';
SELECT id_servicio INTO @id_servicio_alineacion
  FROM servicio WHERE codigo = 'SER-ALIN';
SELECT id_servicio INTO @id_servicio_electrico
  FROM servicio WHERE codigo = 'SER-ELEC';

SELECT id_repuesto INTO @id_repuesto_filtro
  FROM repuesto WHERE codigo = 'REP-FILT-ACE';
SELECT id_repuesto INTO @id_repuesto_aceite
  FROM repuesto WHERE codigo = 'REP-ACE-5W30';
SELECT id_repuesto INTO @id_repuesto_pastillas
  FROM repuesto WHERE codigo = 'REP-PAST-FRE';
SELECT id_repuesto INTO @id_repuesto_bombillo
  FROM repuesto WHERE codigo = 'REP-BOMB-12V';
SELECT id_repuesto INTO @id_repuesto_correa
  FROM repuesto WHERE codigo = 'REP-CORREA';
SELECT id_repuesto INTO @id_repuesto_liquido
  FROM repuesto WHERE codigo = 'REP-LIQ-FRE';

-- ---------------------------------------------------------------------------
-- Historial de precios: 12 filas, 11 vigentes y una cerrada
-- ---------------------------------------------------------------------------

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'servicio',
    @id_servicio_diagnostico,
    15.00,
    30.00,
    '2025-01-15 09:00:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'servicio',
    @id_servicio_diagnostico,
    20.00,
    38.00,
    '2025-06-01 09:00:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'servicio',
    @id_servicio_aceite,
    18.00,
    35.00,
    '2025-06-01 09:01:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'servicio',
    @id_servicio_frenos,
    45.00,
    80.00,
    '2025-06-01 09:02:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'servicio',
    @id_servicio_alineacion,
    20.00,
    40.00,
    '2025-06-01 09:03:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'servicio',
    @id_servicio_electrico,
    25.00,
    50.00,
    '2025-06-01 09:04:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'repuesto',
    @id_repuesto_filtro,
    5.00,
    10.00,
    '2025-06-01 09:05:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'repuesto',
    @id_repuesto_aceite,
    6.00,
    11.00,
    '2025-06-01 09:06:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'repuesto',
    @id_repuesto_pastillas,
    32.00,
    55.00,
    '2025-06-01 09:07:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'repuesto',
    @id_repuesto_bombillo,
    3.00,
    7.00,
    '2025-06-01 09:08:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'repuesto',
    @id_repuesto_correa,
    18.00,
    32.00,
    '2025-06-01 09:09:00',
    @id_precio_creado
);

SET @id_precio_creado = NULL;
CALL sp_registrar_precio(
    @id_usuario_administrador,
    'repuesto',
    @id_repuesto_liquido,
    4.00,
    8.00,
    '2025-06-01 09:10:00',
    @id_precio_creado
);

-- ---------------------------------------------------------------------------
-- Clientes y vehículos mediante el procedimiento oficial
-- ---------------------------------------------------------------------------

SET @id_cliente_persona_1 = NULL;
SET @id_vehiculo_persona_1 = NULL;
CALL sp_crear_cliente_vehiculo(
    @id_usuario_asesor,
    'persona',
    'cedula',
    '1756789012',
    'Elena',
    'Cárdenas',
    NULL,
    '0981000001',
    'elena.cardenas@example.com',
    'Av. del Taller 101',
    'PBA-1001',
    'CHASIS-DEMO-0001',
    'Toyota',
    'Corolla',
    2018,
    'Azul',
    45000,
    @id_cliente_persona_1,
    @id_vehiculo_persona_1
);

SET @id_cliente_persona_2 = NULL;
SET @id_vehiculo_persona_2 = NULL;
CALL sp_crear_cliente_vehiculo(
    @id_usuario_asesor,
    'persona',
    'cedula',
    '1767890123',
    'Fernando',
    'López',
    NULL,
    '0981000002',
    'fernando.lopez@example.com',
    'Calle Mecánica 202',
    'PBB-2002',
    'CHASIS-DEMO-0002',
    'Chevrolet',
    'Sail',
    2019,
    'Plata',
    78200,
    @id_cliente_persona_2,
    @id_vehiculo_persona_2
);

SET @id_cliente_empresa = NULL;
SET @id_vehiculo_empresa = NULL;
CALL sp_crear_cliente_vehiculo(
    @id_usuario_administrador,
    'empresa',
    'ruc',
    '1791234567001',
    NULL,
    NULL,
    'Transportes Demo S.A.',
    '022000003',
    'contacto@transportes-demo.example.com',
    'Parque Industrial, lote 3',
    'PBC-3003',
    'CHASIS-DEMO-0003',
    'Hino',
    'Dutro',
    2017,
    'Blanco',
    120000,
    @id_cliente_empresa,
    @id_vehiculo_empresa
);

-- ---------------------------------------------------------------------------
-- Escenario A: orden finalizada, facturada y pagada
-- ---------------------------------------------------------------------------

SET @id_orden_a = NULL;
CALL sp_crear_orden_trabajo(
    @id_usuario_asesor,
    @id_vehiculo_persona_1,
    @id_mecanico_1,
    'Mantenimiento periódico y ruido al encender',
    'Escenario A',
    45100,
    @id_orden_a
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_mecanico_1,
    @id_orden_a,
    'diagnostico',
    'Inicio de diagnóstico',
    @id_historial_estado
);

SET @orden_actualizada = 0;
CALL sp_actualizar_diagnostico_orden(
    @id_usuario_mecanico_1,
    @id_orden_a,
    'Aceite degradado y filtro próximo al límite de servicio',
    'Se recomienda mantenimiento preventivo',
    @orden_actualizada
);

SET @id_detalle = NULL;
CALL sp_agregar_detalle_orden(
    @id_usuario_mecanico_1,
    @id_orden_a,
    'servicio',
    @id_servicio_aceite,
    1.00,
    'Servicio de cambio de aceite',
    @id_detalle
);

SET @id_detalle = NULL;
CALL sp_agregar_detalle_orden(
    @id_usuario_mecanico_1,
    @id_orden_a,
    'repuesto',
    @id_repuesto_filtro,
    1.00,
    'Filtro nuevo',
    @id_detalle
);

SET @id_detalle = NULL;
CALL sp_agregar_detalle_orden(
    @id_usuario_mecanico_1,
    @id_orden_a,
    'repuesto',
    @id_repuesto_aceite,
    4.00,
    'Cuatro litros de aceite',
    @id_detalle
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_mecanico_1,
    @id_orden_a,
    'en_reparacion',
    'Mantenimiento autorizado',
    @id_historial_estado
);

SET @id_historial_estado = NULL;
CALL sp_finalizar_orden(
    @id_usuario_mecanico_1,
    @id_orden_a,
    'Mantenimiento completado',
    @id_historial_estado
);

SET @id_factura_a = NULL;
CALL sp_generar_factura(
    @id_usuario_asesor,
    @id_orden_a,
    @id_factura_a
);

SELECT total INTO @total_factura_a
  FROM factura
 WHERE id_factura = @id_factura_a;

SET @id_pago_a = NULL;
CALL sp_registrar_pago(
    @id_usuario_asesor,
    @id_factura_a,
    @total_factura_a,
    'transferencia',
    'TRX-DEMO-0001',
    NULL,
    @id_pago_a
);

-- ---------------------------------------------------------------------------
-- Escenario B: factura emitida y pendiente
-- ---------------------------------------------------------------------------

SET @id_orden_b = NULL;
CALL sp_crear_orden_trabajo(
    @id_usuario_asesor,
    @id_vehiculo_persona_2,
    @id_mecanico_2,
    'Vibración y desgaste al frenar',
    'Escenario B',
    78300,
    @id_orden_b
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_mecanico_2,
    @id_orden_b,
    'diagnostico',
    'Inicio de revisión de frenos',
    @id_historial_estado
);

SET @orden_actualizada = 0;
CALL sp_actualizar_diagnostico_orden(
    @id_usuario_mecanico_2,
    @id_orden_b,
    'Sistema de frenos requiere mantenimiento preventivo',
    'No se detectan fugas',
    @orden_actualizada
);

SET @id_detalle = NULL;
CALL sp_agregar_detalle_orden(
    @id_usuario_mecanico_2,
    @id_orden_b,
    'servicio',
    @id_servicio_frenos,
    1.00,
    'Mantenimiento del sistema de frenos',
    @id_detalle
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_mecanico_2,
    @id_orden_b,
    'en_reparacion',
    'Servicio autorizado',
    @id_historial_estado
);

SET @id_historial_estado = NULL;
CALL sp_finalizar_orden(
    @id_usuario_mecanico_2,
    @id_orden_b,
    'Mantenimiento de frenos completado',
    @id_historial_estado
);

SET @id_factura_b = NULL;
CALL sp_generar_factura(
    @id_usuario_asesor,
    @id_orden_b,
    @id_factura_b
);

-- ---------------------------------------------------------------------------
-- Escenario C: orden activa esperando repuestos
-- ---------------------------------------------------------------------------

SET @id_orden_c = NULL;
CALL sp_crear_orden_trabajo(
    @id_usuario_asesor,
    @id_vehiculo_empresa,
    @id_mecanico_1,
    'Falla intermitente en iluminación frontal',
    'Escenario C',
    120100,
    @id_orden_c
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_mecanico_1,
    @id_orden_c,
    'diagnostico',
    'Inicio de diagnóstico eléctrico',
    @id_historial_estado
);

SET @orden_actualizada = 0;
CALL sp_actualizar_diagnostico_orden(
    @id_usuario_mecanico_1,
    @id_orden_c,
    'Bombillo frontal agotado; se verificará disponibilidad',
    'Vehículo permanece en espera',
    @orden_actualizada
);

SET @id_detalle = NULL;
CALL sp_agregar_detalle_orden(
    @id_usuario_mecanico_1,
    @id_orden_c,
    'servicio',
    @id_servicio_electrico,
    1.00,
    'Revisión del circuito de iluminación',
    @id_detalle
);

SET @id_detalle = NULL;
CALL sp_agregar_detalle_orden(
    @id_usuario_mecanico_1,
    @id_orden_c,
    'repuesto',
    @id_repuesto_bombillo,
    1.00,
    'Bombillo de reemplazo reservado',
    @id_detalle
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_mecanico_1,
    @id_orden_c,
    'esperando_repuestos',
    'Pendiente de confirmación logística',
    @id_historial_estado
);

-- ---------------------------------------------------------------------------
-- Escenario D: orden cancelada sin detalles
-- ---------------------------------------------------------------------------

SET @id_orden_d = NULL;
CALL sp_crear_orden_trabajo(
    @id_usuario_asesor,
    @id_vehiculo_persona_1,
    @id_mecanico_1,
    'Revisión solicitada y posteriormente cancelada',
    'Escenario D',
    45200,
    @id_orden_d
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_asesor,
    @id_orden_d,
    'cancelada',
    'Cliente canceló la atención antes del diagnóstico',
    @id_historial_estado
);

-- ---------------------------------------------------------------------------
-- Escenario E: factura anulada sin reversión de inventario
-- ---------------------------------------------------------------------------

SET @id_orden_e = NULL;
CALL sp_crear_orden_trabajo(
    @id_usuario_asesor,
    @id_vehiculo_persona_2,
    @id_mecanico_2,
    'Desalineación perceptible en carretera',
    'Escenario E',
    78400,
    @id_orden_e
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_mecanico_2,
    @id_orden_e,
    'diagnostico',
    'Inicio de diagnóstico de dirección',
    @id_historial_estado
);

SET @orden_actualizada = 0;
CALL sp_actualizar_diagnostico_orden(
    @id_usuario_mecanico_2,
    @id_orden_e,
    'Geometría de dirección fuera de especificación',
    'Se realizará alineación',
    @orden_actualizada
);

SET @id_detalle = NULL;
CALL sp_agregar_detalle_orden(
    @id_usuario_mecanico_2,
    @id_orden_e,
    'servicio',
    @id_servicio_alineacion,
    1.00,
    'Alineación completa',
    @id_detalle
);

SET @id_historial_estado = NULL;
CALL sp_cambiar_estado_orden(
    @id_usuario_mecanico_2,
    @id_orden_e,
    'en_reparacion',
    'Alineación autorizada',
    @id_historial_estado
);

SET @id_historial_estado = NULL;
CALL sp_finalizar_orden(
    @id_usuario_mecanico_2,
    @id_orden_e,
    'Alineación completada',
    @id_historial_estado
);

SET @id_factura_e = NULL;
CALL sp_generar_factura(
    @id_usuario_asesor,
    @id_orden_e,
    @id_factura_e
);

SET @factura_anulada = 0;
CALL sp_anular_factura(
    @id_usuario_administrador,
    @id_factura_e,
    'Anulación demostrativa solicitada por administración',
    @factura_anulada
);

-- Limpieza explícita del contexto de auditoría de la conexión.
SET @app_id_usuario = NULL;
SET @app_origen = NULL;
SET @app_motivo = NULL;

-- ---------------------------------------------------------------------------
-- Resúmenes informativos
-- ---------------------------------------------------------------------------

SELECT 'rol' AS tabla, COUNT(*) AS cantidad FROM rol
UNION ALL
SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL
SELECT 'mecanico', COUNT(*) FROM mecanico
UNION ALL
SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL
SELECT 'vehiculo', COUNT(*) FROM vehiculo
UNION ALL
SELECT 'servicio', COUNT(*) FROM servicio
UNION ALL
SELECT 'repuesto', COUNT(*) FROM repuesto
UNION ALL
SELECT 'historial_precio', COUNT(*) FROM historial_precio
UNION ALL
SELECT 'orden_trabajo', COUNT(*) FROM orden_trabajo
UNION ALL
SELECT 'detalle_orden', COUNT(*) FROM detalle_orden
UNION ALL
SELECT 'factura', COUNT(*) FROM factura
UNION ALL
SELECT 'detalle_factura', COUNT(*) FROM detalle_factura
UNION ALL
SELECT 'pago', COUNT(*) FROM pago
UNION ALL
SELECT 'auditoria', COUNT(*) FROM auditoria;

SELECT * FROM vw_precios_venta_vigentes;
SELECT * FROM vw_historial_vehiculo;
SELECT * FROM vw_ordenes_mecanico;
SELECT * FROM vw_facturas_estado_cobro;

SELECT codigo, nombre, stock_actual, stock_minimo
  FROM repuesto
 ORDER BY codigo;

SELECT tabla_afectada, accion, COUNT(*) AS cantidad
  FROM auditoria
 GROUP BY tabla_afectada, accion
 ORDER BY tabla_afectada, accion;
