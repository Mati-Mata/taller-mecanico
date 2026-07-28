-- Fase 3: índices secundarios para consultas y operaciones críticas.
-- Se ejecuta después de crear las tablas y aplicar sus restricciones.

USE taller_mecanico;

-- Precio vigente o histórico de un servicio.
-- Orden: servicio, fin de vigencia y comienzo temporal.
-- Comparte el prefijo id_servicio con la FK, pero añade las fechas necesarias
-- para filtrar vigencia y ordenar el historial.
CREATE INDEX idx_hp_servicio_vigencia
    ON historial_precio (id_servicio, fecha_fin, fecha_inicio);

-- Precio vigente o histórico de un repuesto.
-- Orden: repuesto, fin de vigencia y comienzo temporal.
-- Comparte el prefijo id_repuesto con la FK, pero añade las fechas necesarias
-- para filtrar vigencia y ordenar el historial.
CREATE INDEX idx_hp_repuesto_vigencia
    ON historial_precio (id_repuesto, fecha_fin, fecha_inicio);

-- Órdenes asignadas a un mecánico, filtradas por estado y ordenadas por fecha.
-- Orden: mecánico, estado y fecha de apertura.
-- Comparte el prefijo id_mecanico con la FK, pero las columnas adicionales
-- permiten comprobar capacidad y recuperar primero el periodo pertinente.
CREATE INDEX idx_ot_mecanico_estado_fecha
    ON orden_trabajo (id_mecanico, estado, fecha_apertura);

-- Historial cronológico de mantenimiento de un vehículo.
-- Orden: vehículo y fecha de apertura.
-- Comparte el prefijo id_vehiculo con la FK, pero añade la fecha requerida para
-- recorrer las órdenes del vehículo cronológicamente.
CREATE INDEX idx_ot_vehiculo_fecha
    ON orden_trabajo (id_vehiculo, fecha_apertura);

-- Panel operativo y reportes de órdenes por estado o periodo.
-- Orden: estado y fecha de apertura para filtrar antes de recorrer el periodo.
-- Su primer campo no corresponde a una FK; el compuesto evita un índice aislado
-- sobre estado y aporta el orden temporal requerido.
CREATE INDEX idx_ot_estado_fecha
    ON orden_trabajo (estado, fecha_apertura);

-- Transiciones de una orden recuperadas en secuencia cronológica.
-- Orden: orden de trabajo y fecha del cambio.
-- Comparte el prefijo id_orden_trabajo con la FK, pero añade fecha_cambio para
-- ordenar eficientemente el historial de una orden.
CREATE INDEX idx_heo_orden_fecha
    ON historial_estado_orden (id_orden_trabajo, fecha_cambio);

-- Repuestos requeridos por una orden para agrupar y descontar inventario.
-- Orden: orden de trabajo y repuesto.
-- Comparte el prefijo id_orden_trabajo con la FK, pero añade id_repuesto para
-- agrupar las cantidades del mismo insumo dentro de la orden.
CREATE INDEX idx_do_orden_repuesto
    ON detalle_orden (id_orden_trabajo, id_repuesto);

-- Servicios realizados en una orden para consulta y agrupación.
-- Orden: orden de trabajo y servicio.
-- Comparte el prefijo id_orden_trabajo con la FK, pero añade id_servicio para
-- agrupar los conceptos de servicio dentro de la orden.
CREATE INDEX idx_do_orden_servicio
    ON detalle_orden (id_orden_trabajo, id_servicio);

-- Facturas emitidas o anuladas durante un periodo.
-- Orden: estado documental y fecha de emisión.
-- Su primer campo no corresponde a una FK; el compuesto evita un índice aislado
-- sobre estado y permite recorrer directamente el intervalo temporal.
CREATE INDEX idx_factura_estado_fecha
    ON factura (estado, fecha_emision);

-- Comprobación de pagos registrados o anulados para una factura.
-- Orden: factura y estado del pago.
-- Comparte el prefijo id_factura con la FK, pero añade estado para resolver la
-- existencia del pago vigente sin recorrer todo su historial.
CREATE INDEX idx_pago_factura_estado
    ON pago (id_factura, estado);

-- Historia cronológica de auditoría para un registro específico.
-- Orden: tabla afectada, identificador lógico y fecha del evento.
-- Su primer campo no corresponde a una FK; la referencia es polimórfica y el
-- compuesto localiza el registro antes de ordenar sus eventos.
CREATE INDEX idx_auditoria_registro_fecha
    ON auditoria (tabla_afectada, id_registro, fecha_evento);

-- Acciones de auditoría realizadas por un usuario en orden cronológico.
-- Orden: usuario y fecha del evento.
-- Comparte el prefijo id_usuario con la FK, pero añade fecha_evento para
-- recuperar sus acciones directamente en secuencia temporal.
CREATE INDEX idx_auditoria_usuario_fecha
    ON auditoria (id_usuario, fecha_evento);
