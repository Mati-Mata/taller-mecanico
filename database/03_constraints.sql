-- Fase 2: restricciones declarativas e integridad referencial.
-- Este archivo se ejecuta después de crear la base y sus 15 tablas.
-- En FK cuyas columnas participan en CHECK se omiten las cláusulas referenciales
-- explícitas por compatibilidad con MySQL; InnoDB aplica NO ACTION, equivalente
-- a RESTRICT.

USE taller_mecanico;

-- rol: dominio, estado lógico y nombre único.
ALTER TABLE rol
    ADD CONSTRAINT uq_rol_nombre UNIQUE (nombre),
    ADD CONSTRAINT ck_rol_nombre
        CHECK (nombre IN ('administrador', 'asesor', 'mecanico')),
    ADD CONSTRAINT ck_rol_activo
        CHECK (activo IN (0, 1));

-- usuario: relación con rol, credenciales únicas y datos obligatorios.
ALTER TABLE usuario
    ADD CONSTRAINT fk_usuario_rol
        FOREIGN KEY (id_rol) REFERENCES rol (id_rol)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT uq_usuario_cedula UNIQUE (cedula),
    ADD CONSTRAINT uq_usuario_nombre_usuario UNIQUE (nombre_usuario),
    ADD CONSTRAINT uq_usuario_correo UNIQUE (correo),
    ADD CONSTRAINT ck_usuario_cedula
        CHECK (cedula REGEXP '^[0-9]{10}$'),
    ADD CONSTRAINT ck_usuario_nombre_usuario
        CHECK (CHAR_LENGTH(TRIM(nombre_usuario)) >= 3),
    ADD CONSTRAINT ck_usuario_password_hash
        CHECK (CHAR_LENGTH(TRIM(password_hash)) > 0),
    ADD CONSTRAINT ck_usuario_nombres
        CHECK (CHAR_LENGTH(TRIM(nombres)) > 0),
    ADD CONSTRAINT ck_usuario_apellidos
        CHECK (CHAR_LENGTH(TRIM(apellidos)) > 0),
    ADD CONSTRAINT ck_usuario_correo
        CHECK (
            correo REGEXP
            '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
        ),
    ADD CONSTRAINT ck_usuario_telefono
        CHECK (
            telefono IS NULL
            OR CHAR_LENGTH(TRIM(telefono)) > 0
        ),
    ADD CONSTRAINT ck_usuario_activo
        CHECK (activo IN (0, 1)),
    ADD CONSTRAINT ck_usuario_desactivacion
        CHECK (
            (activo = 1 AND fecha_desactivacion IS NULL)
            OR
            (activo = 0 AND fecha_desactivacion IS NOT NULL)
        );

-- mecanico: perfil único, dominios técnicos y relación con usuario.
ALTER TABLE mecanico
    ADD CONSTRAINT fk_mecanico_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT uq_mecanico_usuario UNIQUE (id_usuario),
    ADD CONSTRAINT ck_mecanico_especialidad
        CHECK (CHAR_LENGTH(TRIM(especialidad)) > 0),
    ADD CONSTRAINT ck_mecanico_nivel
        CHECK (nivel IN ('junior', 'intermedio', 'senior')),
    ADD CONSTRAINT ck_mecanico_maximo_ordenes
        CHECK (maximo_ordenes_activas > 0),
    ADD CONSTRAINT ck_mecanico_disponibilidad
        CHECK (disponibilidad IN ('disponible', 'no_disponible')),
    ADD CONSTRAINT ck_mecanico_activo
        CHECK (activo IN (0, 1));

-- cliente: identificación, datos según naturaleza y eliminación lógica.
ALTER TABLE cliente
    ADD CONSTRAINT uq_cliente_identificacion UNIQUE (identificacion),
    ADD CONSTRAINT ck_cliente_tipo_cliente
        CHECK (tipo_cliente IN ('persona', 'empresa')),
    ADD CONSTRAINT ck_cliente_tipo_identificacion
        CHECK (tipo_identificacion IN ('cedula', 'ruc')),
    ADD CONSTRAINT ck_cliente_identificacion_digitos
        CHECK (identificacion REGEXP '^[0-9]+$'),
    ADD CONSTRAINT ck_cliente_identificacion_longitud
        CHECK (
            (tipo_identificacion = 'cedula'
                AND CHAR_LENGTH(identificacion) = 10)
            OR
            (tipo_identificacion = 'ruc'
                AND CHAR_LENGTH(identificacion) = 13)
        ),
    ADD CONSTRAINT ck_cliente_datos_tipo
        CHECK (
            (
                tipo_cliente = 'persona'
                AND nombres IS NOT NULL
                AND CHAR_LENGTH(TRIM(nombres)) > 0
                AND apellidos IS NOT NULL
                AND CHAR_LENGTH(TRIM(apellidos)) > 0
                AND razon_social IS NULL
            )
            OR
            (
                tipo_cliente = 'empresa'
                AND razon_social IS NOT NULL
                AND CHAR_LENGTH(TRIM(razon_social)) > 0
                AND nombres IS NULL
                AND apellidos IS NULL
            )
        ),
    ADD CONSTRAINT ck_cliente_telefono
        CHECK (CHAR_LENGTH(TRIM(telefono)) > 0),
    ADD CONSTRAINT ck_cliente_correo
        CHECK (
            correo IS NULL
            OR correo REGEXP
                '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
        ),
    ADD CONSTRAINT ck_cliente_activo
        CHECK (activo IN (0, 1)),
    ADD CONSTRAINT ck_cliente_desactivacion
        CHECK (
            (activo = 1 AND fecha_desactivacion IS NULL)
            OR
            (activo = 0 AND fecha_desactivacion IS NOT NULL)
        );

-- vehiculo: propietario, identificadores únicos y datos físicos válidos.
ALTER TABLE vehiculo
    ADD CONSTRAINT fk_vehiculo_cliente
        FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT uq_vehiculo_placa UNIQUE (placa),
    ADD CONSTRAINT uq_vehiculo_numero_chasis UNIQUE (numero_chasis),
    ADD CONSTRAINT ck_vehiculo_placa
        CHECK (CHAR_LENGTH(TRIM(placa)) > 0),
    ADD CONSTRAINT ck_vehiculo_numero_chasis
        CHECK (
            numero_chasis IS NULL
            OR CHAR_LENGTH(TRIM(numero_chasis)) > 0
        ),
    ADD CONSTRAINT ck_vehiculo_marca
        CHECK (CHAR_LENGTH(TRIM(marca)) > 0),
    ADD CONSTRAINT ck_vehiculo_modelo
        CHECK (CHAR_LENGTH(TRIM(modelo)) > 0),
    ADD CONSTRAINT ck_vehiculo_anio
        CHECK (anio IS NULL OR anio BETWEEN 1886 AND 2100),
    ADD CONSTRAINT ck_vehiculo_kilometraje
        CHECK (kilometraje_actual >= 0),
    ADD CONSTRAINT ck_vehiculo_activo
        CHECK (activo IN (0, 1)),
    ADD CONSTRAINT ck_vehiculo_desactivacion
        CHECK (
            (activo = 1 AND fecha_desactivacion IS NULL)
            OR
            (activo = 0 AND fecha_desactivacion IS NOT NULL)
        );

-- servicio: código único y catálogo lógico válido.
ALTER TABLE servicio
    ADD CONSTRAINT uq_servicio_codigo UNIQUE (codigo),
    ADD CONSTRAINT ck_servicio_codigo
        CHECK (CHAR_LENGTH(TRIM(codigo)) > 0),
    ADD CONSTRAINT ck_servicio_nombre
        CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    ADD CONSTRAINT ck_servicio_categoria
        CHECK (
            categoria IS NULL
            OR CHAR_LENGTH(TRIM(categoria)) > 0
        ),
    ADD CONSTRAINT ck_servicio_duracion
        CHECK (
            duracion_estimada_minutos IS NULL
            OR duracion_estimada_minutos > 0
        ),
    ADD CONSTRAINT ck_servicio_activo
        CHECK (activo IN (0, 1));

-- repuesto: código único, existencias y unidad de medida.
ALTER TABLE repuesto
    ADD CONSTRAINT uq_repuesto_codigo UNIQUE (codigo),
    ADD CONSTRAINT ck_repuesto_codigo
        CHECK (CHAR_LENGTH(TRIM(codigo)) > 0),
    ADD CONSTRAINT ck_repuesto_nombre
        CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    ADD CONSTRAINT ck_repuesto_marca
        CHECK (
            marca IS NULL
            OR CHAR_LENGTH(TRIM(marca)) > 0
        ),
    ADD CONSTRAINT ck_repuesto_stock_actual
        CHECK (stock_actual >= 0),
    ADD CONSTRAINT ck_repuesto_stock_minimo
        CHECK (stock_minimo >= 0),
    ADD CONSTRAINT ck_repuesto_unidad_medida
        CHECK (CHAR_LENGTH(TRIM(unidad_medida)) > 0),
    ADD CONSTRAINT ck_repuesto_activo
        CHECK (activo IN (0, 1));

-- historial_precio: concepto exclusivo, importes y vigencia temporal.
ALTER TABLE historial_precio
    ADD CONSTRAINT fk_historial_precio_servicio
        FOREIGN KEY (id_servicio) REFERENCES servicio (id_servicio),
    ADD CONSTRAINT fk_historial_precio_repuesto
        FOREIGN KEY (id_repuesto) REFERENCES repuesto (id_repuesto),
    ADD CONSTRAINT fk_historial_precio_usuario_creador
        FOREIGN KEY (id_usuario_creador) REFERENCES usuario (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_historial_precio_concepto
        CHECK (
            (id_servicio IS NOT NULL AND id_repuesto IS NULL)
            OR
            (id_servicio IS NULL AND id_repuesto IS NOT NULL)
        ),
    ADD CONSTRAINT ck_historial_precio_costo
        CHECK (costo_base >= 0),
    ADD CONSTRAINT ck_historial_precio_venta
        CHECK (precio_venta >= costo_base),
    ADD CONSTRAINT ck_historial_precio_fechas
        CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio);

-- orden_trabajo: relaciones, dominio de estado y coherencia terminal.
ALTER TABLE orden_trabajo
    ADD CONSTRAINT fk_orden_trabajo_vehiculo
        FOREIGN KEY (id_vehiculo) REFERENCES vehiculo (id_vehiculo)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_orden_trabajo_mecanico
        FOREIGN KEY (id_mecanico) REFERENCES mecanico (id_mecanico)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_orden_trabajo_usuario_apertura
        FOREIGN KEY (id_usuario_apertura) REFERENCES usuario (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_orden_trabajo_estado
        CHECK (
            estado IN (
                'ingresada',
                'diagnostico',
                'esperando_repuestos',
                'en_reparacion',
                'finalizada',
                'cancelada'
            )
        ),
    ADD CONSTRAINT ck_orden_trabajo_descripcion
        CHECK (CHAR_LENGTH(TRIM(descripcion_problema)) > 0),
    ADD CONSTRAINT ck_orden_trabajo_diagnostico
        CHECK (
            diagnostico IS NULL
            OR CHAR_LENGTH(TRIM(diagnostico)) > 0
        ),
    ADD CONSTRAINT ck_orden_trabajo_kilometraje
        CHECK (kilometraje_ingreso >= 0),
    ADD CONSTRAINT ck_orden_trabajo_inventario
        CHECK (inventario_descontado IN (0, 1)),
    ADD CONSTRAINT ck_orden_trabajo_estado_terminal
        CHECK (
            (
                estado = 'finalizada'
                AND inventario_descontado = 1
                AND fecha_finalizacion IS NOT NULL
            )
            OR
            (
                estado <> 'finalizada'
                AND inventario_descontado = 0
                AND fecha_finalizacion IS NULL
            )
        ),
    ADD CONSTRAINT ck_orden_trabajo_fecha_finalizacion
        CHECK (
            fecha_finalizacion IS NULL
            OR fecha_finalizacion >= fecha_apertura
        );

-- historial_estado_orden: relaciones y consistencia de cada transición.
ALTER TABLE historial_estado_orden
    ADD CONSTRAINT fk_historial_estado_orden_orden_trabajo
        FOREIGN KEY (id_orden_trabajo)
        REFERENCES orden_trabajo (id_orden_trabajo)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_historial_estado_orden_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_historial_estado_orden_anterior
        CHECK (
            estado_anterior IS NULL
            OR estado_anterior IN (
                'ingresada',
                'diagnostico',
                'esperando_repuestos',
                'en_reparacion',
                'finalizada',
                'cancelada'
            )
        ),
    ADD CONSTRAINT ck_historial_estado_orden_nuevo
        CHECK (
            estado_nuevo IN (
                'ingresada',
                'diagnostico',
                'esperando_repuestos',
                'en_reparacion',
                'finalizada',
                'cancelada'
            )
        ),
    ADD CONSTRAINT ck_historial_estado_orden_inicial
        CHECK (
            estado_anterior IS NOT NULL
            OR estado_nuevo = 'ingresada'
        ),
    ADD CONSTRAINT ck_historial_estado_orden_diferente
        CHECK (
            estado_anterior IS NULL
            OR estado_anterior <> estado_nuevo
        );

-- detalle_orden: relaciones, concepto exclusivo e importes congelados.
ALTER TABLE detalle_orden
    ADD CONSTRAINT fk_detalle_orden_orden_trabajo
        FOREIGN KEY (id_orden_trabajo)
        REFERENCES orden_trabajo (id_orden_trabajo)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_detalle_orden_servicio
        FOREIGN KEY (id_servicio) REFERENCES servicio (id_servicio),
    ADD CONSTRAINT fk_detalle_orden_repuesto
        FOREIGN KEY (id_repuesto) REFERENCES repuesto (id_repuesto),
    ADD CONSTRAINT fk_detalle_orden_historial_precio
        FOREIGN KEY (id_historial_precio)
        REFERENCES historial_precio (id_historial_precio)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_detalle_orden_concepto
        CHECK (
            (id_servicio IS NOT NULL AND id_repuesto IS NULL)
            OR
            (id_servicio IS NULL AND id_repuesto IS NOT NULL)
        ),
    ADD CONSTRAINT ck_detalle_orden_descripcion
        CHECK (CHAR_LENGTH(TRIM(descripcion_concepto)) > 0),
    ADD CONSTRAINT ck_detalle_orden_cantidad
        CHECK (cantidad > 0),
    ADD CONSTRAINT ck_detalle_orden_precio
        CHECK (precio_unitario >= 0),
    ADD CONSTRAINT ck_detalle_orden_subtotal
        CHECK (subtotal >= 0),
    ADD CONSTRAINT ck_detalle_orden_calculo
        CHECK (subtotal = ROUND(cantidad * precio_unitario, 2));

-- factura: relaciones, una factura por orden, totales e inmutabilidad lógica.
ALTER TABLE factura
    ADD CONSTRAINT fk_factura_orden_trabajo
        FOREIGN KEY (id_orden_trabajo)
        REFERENCES orden_trabajo (id_orden_trabajo)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_factura_usuario_emision
        FOREIGN KEY (id_usuario_emision) REFERENCES usuario (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_factura_usuario_anulacion
        FOREIGN KEY (id_usuario_anulacion) REFERENCES usuario (id_usuario),
    ADD CONSTRAINT uq_factura_orden UNIQUE (id_orden_trabajo),
    ADD CONSTRAINT ck_factura_estado
        CHECK (estado IN ('emitida', 'anulada')),
    ADD CONSTRAINT ck_factura_identificacion_cliente
        CHECK (identificacion_cliente REGEXP '^([0-9]{10}|[0-9]{13})$'),
    ADD CONSTRAINT ck_factura_nombre_cliente
        CHECK (CHAR_LENGTH(TRIM(nombre_cliente)) > 0),
    ADD CONSTRAINT ck_factura_placa_vehiculo
        CHECK (CHAR_LENGTH(TRIM(placa_vehiculo)) > 0),
    ADD CONSTRAINT ck_factura_subtotal
        CHECK (subtotal >= 0),
    ADD CONSTRAINT ck_factura_porcentaje_iva
        CHECK (porcentaje_iva = 15.00),
    ADD CONSTRAINT ck_factura_valor_iva
        CHECK (
            valor_iva = ROUND(subtotal * porcentaje_iva / 100, 2)
        ),
    ADD CONSTRAINT ck_factura_total
        CHECK (total = subtotal + valor_iva),
    ADD CONSTRAINT ck_factura_anulacion
        CHECK (
            (
                estado = 'emitida'
                AND fecha_anulacion IS NULL
                AND id_usuario_anulacion IS NULL
                AND motivo_anulacion IS NULL
            )
            OR
            (
                estado = 'anulada'
                AND fecha_anulacion IS NOT NULL
                AND id_usuario_anulacion IS NOT NULL
                AND motivo_anulacion IS NOT NULL
                AND CHAR_LENGTH(TRIM(motivo_anulacion)) > 0
            )
        ),
    ADD CONSTRAINT ck_factura_fecha_anulacion
        CHECK (
            fecha_anulacion IS NULL
            OR fecha_anulacion >= fecha_emision
        );

-- detalle_factura: origen único e instantánea de importes.
ALTER TABLE detalle_factura
    ADD CONSTRAINT fk_detalle_factura_factura
        FOREIGN KEY (id_factura) REFERENCES factura (id_factura)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_detalle_factura_detalle_orden
        FOREIGN KEY (id_detalle_orden)
        REFERENCES detalle_orden (id_detalle_orden)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT uq_detalle_factura_detalle_orden
        UNIQUE (id_detalle_orden),
    ADD CONSTRAINT ck_detalle_factura_tipo
        CHECK (tipo_concepto IN ('servicio', 'repuesto')),
    ADD CONSTRAINT ck_detalle_factura_codigo
        CHECK (CHAR_LENGTH(TRIM(codigo_concepto)) > 0),
    ADD CONSTRAINT ck_detalle_factura_descripcion
        CHECK (CHAR_LENGTH(TRIM(descripcion_concepto)) > 0),
    ADD CONSTRAINT ck_detalle_factura_cantidad
        CHECK (cantidad > 0),
    ADD CONSTRAINT ck_detalle_factura_precio
        CHECK (precio_unitario >= 0),
    ADD CONSTRAINT ck_detalle_factura_subtotal
        CHECK (subtotal >= 0),
    ADD CONSTRAINT ck_detalle_factura_calculo
        CHECK (subtotal = ROUND(cantidad * precio_unitario, 2));

-- pago: relaciones, dominios, referencia y anulación.
ALTER TABLE pago
    ADD CONSTRAINT fk_pago_factura
        FOREIGN KEY (id_factura) REFERENCES factura (id_factura)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_pago_usuario_registro
        FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_pago_usuario_anulacion
        FOREIGN KEY (id_usuario_anulacion) REFERENCES usuario (id_usuario),
    ADD CONSTRAINT ck_pago_monto
        CHECK (monto > 0),
    ADD CONSTRAINT ck_pago_metodo
        CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia')),
    ADD CONSTRAINT ck_pago_estado
        CHECK (estado IN ('registrado', 'anulado')),
    ADD CONSTRAINT ck_pago_referencia
        CHECK (
            (
                metodo_pago IN ('tarjeta', 'transferencia')
                AND referencia IS NOT NULL
                AND CHAR_LENGTH(TRIM(referencia)) > 0
            )
            OR
            (
                metodo_pago = 'efectivo'
                AND (
                    referencia IS NULL
                    OR CHAR_LENGTH(TRIM(referencia)) > 0
                )
            )
        ),
    ADD CONSTRAINT ck_pago_anulacion
        CHECK (
            (
                estado = 'registrado'
                AND fecha_anulacion IS NULL
                AND id_usuario_anulacion IS NULL
                AND motivo_anulacion IS NULL
            )
            OR
            (
                estado = 'anulado'
                AND fecha_anulacion IS NOT NULL
                AND id_usuario_anulacion IS NOT NULL
                AND motivo_anulacion IS NOT NULL
                AND CHAR_LENGTH(TRIM(motivo_anulacion)) > 0
            )
        ),
    ADD CONSTRAINT ck_pago_fecha_anulacion
        CHECK (
            fecha_anulacion IS NULL
            OR fecha_anulacion >= fecha_pago
        );

-- auditoria: actor opcional y referencia lógica polimórfica.
ALTER TABLE auditoria
    ADD CONSTRAINT fk_auditoria_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT ck_auditoria_tabla
        CHECK (CHAR_LENGTH(TRIM(tabla_afectada)) > 0),
    ADD CONSTRAINT ck_auditoria_id_registro
        CHECK (id_registro > 0),
    ADD CONSTRAINT ck_auditoria_accion
        CHECK (CHAR_LENGTH(TRIM(accion)) > 0),
    ADD CONSTRAINT ck_auditoria_motivo
        CHECK (
            motivo IS NULL
            OR CHAR_LENGTH(TRIM(motivo)) > 0
        ),
    ADD CONSTRAINT ck_auditoria_origen
        CHECK (
            origen IS NULL
            OR CHAR_LENGTH(TRIM(origen)) > 0
        ),
    ADD CONSTRAINT ck_auditoria_direccion_ip
        CHECK (
            direccion_ip IS NULL
            OR CHAR_LENGTH(TRIM(direccion_ip)) > 0
        );
