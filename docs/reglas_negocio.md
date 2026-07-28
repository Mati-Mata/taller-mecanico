# Reglas de negocio

Cada regla identifica su validación futura. Los ejemplos son conceptuales y no
constituyen SQL.

## Roles, usuarios y mecánicos

### RN-USU-001 — Rol obligatorio

- **Descripción:** cada usuario tiene exactamente un rol activo al crearse.
- **Tablas:** `usuario`, `rol`.
- **Momento:** alta de usuario y cambio de rol.
- **Mecanismo:** FK, procedimiento/aplicación.
- **Válido:** crear a Ana con rol asesor activo.
- **Inválido:** crear un usuario sin rol o con un rol inactivo.

### RN-USU-002 — Credenciales únicas y seguras

- **Descripción:** nombre de usuario y correo son únicos; solo se guarda hash.
- **Tablas:** `usuario`.
- **Momento:** alta y actualización.
- **Mecanismo:** UNIQUE, CHECK básico, aplicación.
- **Válido:** `ana.perez` con un hash no vacío.
- **Inválido:** repetir `ana.perez` o guardar una contraseña plana.

### RN-MEC-001 — Perfil técnico único

- **Descripción:** un usuario puede tener como máximo un perfil de mecánico y
  debe poseer el rol `mecanico`.
- **Tablas:** `mecanico`, `usuario`, `rol`.
- **Momento:** alta/cambio del perfil o rol.
- **Mecanismo:** UNIQUE, FK, procedimiento, trigger.
- **Válido:** vincular un perfil al usuario con rol mecánico.
- **Inválido:** dos perfiles para el mismo usuario o perfil para un asesor.

### RN-MEC-002 — Capacidad y disponibilidad

- **Descripción:** solo un mecánico activo y disponible puede recibir una orden,
  sin superar `maximo_ordenes_activas`.
- **Tablas:** `mecanico`, `orden_trabajo`.
- **Momento:** creación o reasignación de orden.
- **Mecanismo:** procedimiento con bloqueo.
- **Válido:** asignar la tercera orden activa si el máximo es tres.
- **Inválido:** asignar una cuarta orden o asignar a alguien no disponible.

## Clientes

### RN-CLI-001 — Identificación única y numérica

- **Descripción:** la identificación no se repite y contiene solo dígitos.
- **Tablas:** `cliente`.
- **Momento:** alta y actualización.
- **Mecanismo:** UNIQUE, CHECK.
- **Válido:** cédula ficticia de diez dígitos no registrada.
- **Inválido:** documento con letras o ya existente.

### RN-CLI-002 — Longitud según tipo

- **Descripción:** `cedula` exige 10 dígitos y `ruc` exige 13; no se valida el
  dígito verificador.
- **Tablas:** `cliente`.
- **Momento:** alta y actualización.
- **Mecanismo:** CHECK.
- **Válido:** tipo `ruc` con 13 dígitos.
- **Inválido:** tipo `cedula` con 13 dígitos.

### RN-CLI-003 — Datos según naturaleza

- **Descripción:** una persona requiere nombres y apellidos y no razón social;
  una empresa requiere razón social y no nombres/apellidos.
- **Tablas:** `cliente`.
- **Momento:** alta y actualización.
- **Mecanismo:** CHECK.
- **Válido:** empresa con razón social ficticia.
- **Inválido:** persona sin apellidos.

### RN-CLI-004 — Desactivación lógica

- **Descripción:** un cliente con historia se desactiva, no se elimina.
- **Tablas:** `cliente`, `vehiculo`, `auditoria`.
- **Momento:** solicitud de baja.
- **Mecanismo:** procedimiento/aplicación, FK, trigger de auditoría.
- **Válido:** cambiar `activo` a 0 y registrar fecha y auditoría.
- **Inválido:** borrar físicamente un cliente propietario de vehículos.

## Vehículos

### RN-VEH-001 — Propietario obligatorio

- **Descripción:** cada vehículo pertenece a un cliente existente y activo al
  momento del alta.
- **Tablas:** `vehiculo`, `cliente`.
- **Momento:** alta.
- **Mecanismo:** FK, procedimiento/aplicación.
- **Válido:** registrar vehículo para un cliente activo.
- **Inválido:** registrar sin cliente o con cliente inexistente.

### RN-VEH-002 — Placa y chasis únicos

- **Descripción:** placa normalizada es única y chasis es único cuando se informa.
- **Tablas:** `vehiculo`.
- **Momento:** alta y actualización.
- **Mecanismo:** UNIQUE, aplicación/procedimiento para normalización.
- **Válido:** placa nueva y chasis nulo.
- **Inválido:** repetir una placa con distinta combinación de mayúsculas.

### RN-VEH-003 — Conservación de historial

- **Descripción:** el vehículo se desactiva lógicamente y sus órdenes permanecen.
- **Tablas:** `vehiculo`, `orden_trabajo`, `auditoria`.
- **Momento:** baja.
- **Mecanismo:** FK, procedimiento/aplicación, trigger.
- **Válido:** desactivar un vehículo después de finalizar su orden.
- **Inválido:** eliminarlo físicamente y perder trazabilidad.

## Servicios, repuestos y precios

### RN-PRE-001 — Concepto exclusivo del precio

- **Descripción:** cada historial de precio pertenece exactamente a un servicio
  o a un repuesto.
- **Tablas:** `historial_precio`, `servicio`, `repuesto`.
- **Momento:** inserción y actualización.
- **Mecanismo:** CHECK XOR, FK.
- **Válido:** precio con `id_servicio` y `id_repuesto` nulo.
- **Inválido:** ambos informados o ambos nulos.

### RN-PRE-002 — Importes válidos

- **Descripción:** costo y venta son no negativos y venta no es menor al costo.
- **Tablas:** `historial_precio`.
- **Momento:** alta.
- **Mecanismo:** CHECK.
- **Válido:** costo 20.00, venta 28.00.
- **Inválido:** costo 20.00, venta 18.00.

### RN-PRE-003 — Una sola vigencia actual

- **Descripción:** solo existe un precio con `fecha_fin` nula por concepto.
- **Tablas:** `historial_precio`, `servicio`, `repuesto`.
- **Momento:** nuevo precio o modificación de vigencia.
- **Mecanismo:** procedimiento transaccional con bloqueo, trigger defensivo.
- **Válido:** cerrar el vigente e insertar el nuevo en la misma transacción.
- **Inválido:** dos precios vigentes para el mismo repuesto.

### RN-PRE-004 — Vigencias sin solapamiento

- **Descripción:** los intervalos de un concepto no se superponen y el fin es
  posterior al inicio.
- **Tablas:** `historial_precio`.
- **Momento:** alta/actualización.
- **Mecanismo:** CHECK para orden temporal; procedimiento y trigger para solape.
- **Válido:** nueva vigencia que comienza al cerrar la anterior.
- **Inválido:** intervalo que atraviesa otro ya registrado.

### RN-PRE-005 — Precio usado inmutable

- **Descripción:** un precio referenciado por una orden/factura no se elimina ni
  altera.
- **Tablas:** `historial_precio`, `detalle_orden`.
- **Momento:** intento de actualización o eliminación.
- **Mecanismo:** FK, trigger, permisos de aplicación.
- **Válido:** crear una nueva vigencia.
- **Inválido:** cambiar el precio de un historial ya usado.

### RN-PRE-006 — Costo protegido

- **Descripción:** el asesor consulta precios vigentes sin ver costo base.
- **Tablas:** `historial_precio`, `servicio`, `repuesto`.
- **Momento:** consulta.
- **Mecanismo:** vista y permisos futuros.
- **Válido:** consultar código, concepto y precio de venta.
- **Inválido:** exponer `costo_base` mediante la vista de asesor.

### RN-INV-001 — Stock no negativo

- **Descripción:** `stock_actual` nunca puede ser menor que cero.
- **Tablas:** `repuesto`.
- **Momento:** cualquier cambio de stock.
- **Mecanismo:** CHECK, procedimiento.
- **Válido:** descontar 2 de un stock 5 y dejar 3.
- **Inválido:** descontar 6 de un stock 5.

### RN-INV-002 — Descuento al finalizar

- **Descripción:** el stock de todos los repuestos se descuenta únicamente al
  finalizar la orden y solo si alcanza.
- **Tablas:** `orden_trabajo`, `detalle_orden`, `repuesto`.
- **Momento:** transición a `finalizada`.
- **Mecanismo:** procedimiento transaccional con bloqueos.
- **Válido:** validar todos los repuestos y confirmar todos los descuentos.
- **Inválido:** descontar parcialmente y confirmar aunque otro repuesto falte.

### RN-INV-003 — Descuento único

- **Descripción:** una orden no descuenta inventario más de una vez.
- **Tablas:** `orden_trabajo`, `repuesto`.
- **Momento:** finalización y reintentos.
- **Mecanismo:** CHECK, procedimiento con `FOR UPDATE`, trigger defensivo.
- **Válido:** primer intento marca `inventario_descontado = 1`.
- **Inválido:** reintento que vuelve a reducir stock.

## Órdenes y detalles

### RN-ORD-001 — Relaciones obligatorias

- **Descripción:** toda orden tiene un vehículo, un mecánico responsable y un
  usuario de apertura.
- **Tablas:** `orden_trabajo`, `vehiculo`, `mecanico`, `usuario`.
- **Momento:** alta.
- **Mecanismo:** NOT NULL, FK, procedimiento.
- **Válido:** abrir una orden con las tres referencias activas.
- **Inválido:** abrir sin mecánico.

### RN-ORD-002 — Estado inicial e historial

- **Descripción:** la orden nace `ingresada` y se registra una fila inicial de
  historial con estado anterior nulo.
- **Tablas:** `orden_trabajo`, `historial_estado_orden`.
- **Momento:** alta.
- **Mecanismo:** valor predeterminado, procedimiento, trigger defensivo.
- **Válido:** crear ambas filas en una transacción.
- **Inválido:** crear una orden en `finalizada` sin historial.

### RN-ORD-003 — Transiciones permitidas

- **Descripción:** el estado solo cambia según la matriz final; finalizada y
  cancelada son terminales.
- **Tablas:** `orden_trabajo`, `historial_estado_orden`.
- **Momento:** cambio de estado.
- **Mecanismo:** CHECK de dominio, procedimiento, trigger.
- **Válido:** `diagnostico` a `en_reparacion`.
- **Inválido:** `finalizada` a `en_reparacion`.

### RN-ORD-004 — Historial inmutable

- **Descripción:** cada cambio guarda anterior, nuevo, usuario, fecha y nota
  opcional, sin editar ni eliminar filas previas.
- **Tablas:** `historial_estado_orden`, `usuario`.
- **Momento:** transición e intento de modificación.
- **Mecanismo:** procedimiento, trigger, permisos.
- **Válido:** agregar una nueva transición.
- **Inválido:** corregir una transición sobrescribiendo la fila anterior.

### RN-ORD-005 — Concepto exclusivo

- **Descripción:** cada detalle contiene servicio o repuesto, exactamente uno.
- **Tablas:** `detalle_orden`, `servicio`, `repuesto`.
- **Momento:** alta/actualización del detalle.
- **Mecanismo:** CHECK XOR, FK.
- **Válido:** una línea de servicio sin repuesto.
- **Inválido:** servicio y repuesto en la misma línea.

### RN-ORD-006 — Cantidad y precio congelado

- **Descripción:** cantidad es positiva; el precio vigente se referencia y copia,
  y el subtotal coincide con cantidad por precio redondeado.
- **Tablas:** `detalle_orden`, `historial_precio`.
- **Momento:** alta del detalle.
- **Mecanismo:** CHECK, FK, procedimiento.
- **Válido:** 2 × 15.50 produce subtotal 31.00.
- **Inválido:** cantidad cero o precio histórico de otro concepto.

### RN-ORD-007 — Inmutabilidad terminal

- **Descripción:** no se agregan, cambian ni eliminan detalles de una orden
  finalizada o cancelada.
- **Tablas:** `orden_trabajo`, `detalle_orden`.
- **Momento:** escritura de detalle.
- **Mecanismo:** procedimiento, trigger.
- **Válido:** editar detalle mientras está en diagnóstico.
- **Inválido:** agregar un repuesto después de finalizar.

## Facturación

### RN-FAC-001 — Una factura por orden finalizada

- **Descripción:** una orden genera como máximo una factura y solo si está
  finalizada.
- **Tablas:** `factura`, `orden_trabajo`.
- **Momento:** emisión.
- **Mecanismo:** UNIQUE, FK, procedimiento con bloqueo.
- **Válido:** emitir la primera factura de una orden finalizada.
- **Inválido:** facturar orden en reparación o facturarla dos veces.

### RN-FAC-002 — Numeración automática única

- **Descripción:** el número se genera automáticamente, sin colisiones.
- **Tablas:** `factura`.
- **Momento:** emisión.
- **Mecanismo:** UNIQUE, procedimiento con bloqueo.
- **Válido:** asignar el siguiente correlativo dentro de la transacción.
- **Inválido:** aceptar manualmente un número ya usado.

### RN-FAC-003 — Totales e IVA congelados

- **Descripción:** subtotal es la suma de líneas; IVA es 15 % del subtotal,
  redondeado a dos decimales; total es su suma.
- **Tablas:** `factura`, `detalle_factura`.
- **Momento:** emisión.
- **Mecanismo:** CHECK, procedimiento.
- **Válido:** subtotal 100.00, IVA 15.00, total 115.00.
- **Inválido:** subtotal 100.00 y total 110.00.

### RN-FAC-004 — Trazabilidad de cada línea

- **Descripción:** cada detalle de factura proviene de un detalle de la misma
  orden y este origen se usa una sola vez.
- **Tablas:** `factura`, `detalle_factura`, `detalle_orden`.
- **Momento:** emisión.
- **Mecanismo:** FK, UNIQUE, procedimiento.
- **Válido:** copiar todas las líneas de la orden facturada.
- **Inválido:** copiar una línea de otra orden.

### RN-FAC-005 — Instantánea e inmutabilidad

- **Descripción:** detalle guarda tipo, código, descripción, cantidad, precio y
  subtotal; una factura emitida no se edita.
- **Tablas:** `factura`, `detalle_factura`, `auditoria`.
- **Momento:** emisión e intentos posteriores.
- **Mecanismo:** procedimiento, trigger.
- **Válido:** cambiar luego el nombre del servicio sin afectar la factura.
- **Inválido:** actualizar el precio de una línea emitida.

### RN-FAC-006 — Anulación conservada

- **Descripción:** la factura se anula con usuario, fecha y motivo, nunca se
  borra. No se anula si conserva un pago registrado.
- **Tablas:** `factura`, `pago`, `auditoria`.
- **Momento:** anulación.
- **Mecanismo:** procedimiento con bloqueo, trigger.
- **Válido:** anular factura no pagada registrando motivo.
- **Inválido:** borrar la factura o anularla con pago vigente.

## Pagos

### RN-PAG-001 — Pago total exacto

- **Descripción:** el monto debe ser igual al total de una factura emitida.
- **Tablas:** `pago`, `factura`.
- **Momento:** registro.
- **Mecanismo:** CHECK positivo, procedimiento.
- **Válido:** pagar 115.00 sobre total 115.00.
- **Inválido:** pagar 50.00 o 120.00.

### RN-PAG-002 — Un solo pago vigente

- **Descripción:** puede haber pagos históricos anulados, pero solo uno
  `registrado` por factura.
- **Tablas:** `pago`, `factura`.
- **Momento:** registro/anulación.
- **Mecanismo:** procedimiento con bloqueo, trigger defensivo.
- **Válido:** registrar otro pago después de anular el anterior.
- **Inválido:** dos pagos registrados simultáneamente.

### RN-PAG-003 — Estado pagado derivado

- **Descripción:** una factura se considera pagada por la existencia de un pago
  registrado, no por un estado manual.
- **Tablas:** `factura`, `pago`.
- **Momento:** consulta.
- **Mecanismo:** vista.
- **Válido:** la vista informa pagada cuando encuentra el pago.
- **Inválido:** marcar manualmente pagada sin registro de pago.

### RN-PAG-004 — Anulación trazable

- **Descripción:** anular conserva pago, fecha, usuario y motivo.
- **Tablas:** `pago`, `usuario`, `auditoria`.
- **Momento:** anulación.
- **Mecanismo:** procedimiento, CHECK de coherencia, trigger.
- **Válido:** cambiar a anulado con todos los datos.
- **Inválido:** borrar el pago o anular sin motivo.

## Auditoría

### RN-AUD-001 — Eventos mínimos

- **Descripción:** se auditan cambios de precio y estado, factura, pago,
  desactivaciones y operaciones administrativas sensibles.
- **Tablas:** `auditoria` y tablas afectadas.
- **Momento:** operación sensible confirmada.
- **Mecanismo:** trigger y procedimiento.
- **Válido:** registrar antes/después al desactivar cliente.
- **Inválido:** cambiar un precio sin evidencia.

### RN-AUD-002 — Datos de auditoría

- **Descripción:** cada evento identifica acción, tabla, registro, fecha y actor
  cuando esté disponible; usa JSON para imágenes anterior/nueva.
- **Tablas:** `auditoria`, `usuario`.
- **Momento:** inserción del evento.
- **Mecanismo:** NOT NULL, FK, trigger/procedimiento.
- **Válido:** evento con registro afectado y JSON nuevo.
- **Inválido:** evento sin acción ni tabla.

### RN-AUD-003 — Auditoría inmutable

- **Descripción:** los eventos son append-only y no se eliminan por cascada.
- **Tablas:** `auditoria`.
- **Momento:** intento de actualización/eliminación.
- **Mecanismo:** trigger y permisos.
- **Válido:** añadir un evento correctivo separado.
- **Inválido:** reescribir el JSON de un evento histórico.

## Matriz de estados de orden

| Estado actual | Siguientes permitidos | Siguientes prohibidos | Observación |
|---|---|---|---|
| `ingresada` | `diagnostico`, `cancelada` | `esperando_repuestos`, `en_reparacion`, `finalizada` | Debe pasar por diagnóstico antes de operar. |
| `diagnostico` | `esperando_repuestos`, `en_reparacion`, `cancelada` | `ingresada`, `finalizada` | Puede esperar insumos o iniciar reparación. |
| `esperando_repuestos` | `en_reparacion`, `cancelada` | `ingresada`, `diagnostico`, `finalizada` | Sale al disponer de repuestos. |
| `en_reparacion` | `esperando_repuestos`, `finalizada`, `cancelada` | `ingresada`, `diagnostico` | Finalizar ejecuta validación y descuento de stock. |
| `finalizada` | Ninguno | Todos | Terminal e irreversible. |
| `cancelada` | Ninguno | Todos | Terminal; un problema posterior crea otra orden. |

No se admiten transiciones al mismo estado. Toda transición permitida genera
historial en la misma transacción.

## Estados propuestos

| Entidad | Estado | Significado |
|---|---|---|
| Factura | `emitida` | Documento vigente; su cobro se deriva de pagos. |
| Factura | `anulada` | Documento invalidado y conservado. |
| Pago | `registrado` | Pago total vigente que cubre la factura. |
| Pago | `anulado` | Pago invalidado y conservado. |
| Mecánico | `disponible` | Puede recibir órdenes si no supera su máximo. |
| Mecánico | `no_disponible` | No puede recibir nuevas órdenes. |
| Maestros con baja lógica | `activo = 1` | Disponible para nuevas operaciones. |
| Maestros con baja lógica | `activo = 0` | Inactivo, visible solo por historia/administración. |

Los maestros con eliminación lógica son `rol`, `usuario`, `mecanico`, `cliente`,
`vehiculo`, `servicio` y `repuesto`. Desactivar no equivale a borrar ni modifica
documentos existentes.

