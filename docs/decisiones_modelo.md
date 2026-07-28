# Decisiones del modelo físico

## 1. Alcance de la base de datos

La base de datos administrará cuentas y roles de la aplicación, clientes, vehículos,
catálogos de servicios y repuestos, precios históricos, inventario, órdenes de
trabajo, facturación, pagos y auditoría. El diseño está orientado a MySQL Server
8.0, InnoDB y `utf8mb4`, y podrá ser consumido posteriormente por un backend.

Quedan fuera de esta fase y del alcance funcional actual: autenticación técnica del
backend, permisos de MySQL, interfaz web, pagos parciales, facturación consolidada,
varios mecánicos responsables por orden y validación matemática de cédula o RUC.
Esta Fase 0 no contiene SQL ejecutable.

## 2. Convenciones generales

- Nombres en español, minúsculas y `snake_case`; tablas en singular.
- PK `id_<tabla>` de tipo `INT UNSIGNED AUTO_INCREMENT`.
- FK con el mismo nombre de la PK referenciada.
- Restricciones nombradas con prefijos `pk_`, `fk_`, `uq_` y `ck_`.
- Dinero en `DECIMAL(12,2)` y dólares estadounidenses.
- Fechas de negocio con hora en `DATETIME`; fechas de calendario en `DATE`.
- Estados en `VARCHAR` con `CHECK`, evitando `ENUM`.
- Contraseñas únicamente como `password_hash VARCHAR(255)`.
- `ON DELETE RESTRICT` y `ON UPDATE RESTRICT` como reglas generales.
- Eliminación lógica para maestros con historial.
- Todas las operaciones críticas de varias tablas serán transaccionales.

## 3. Lista definitiva de tablas

No se propone ninguna entidad adicional. Las 15 tablas definitivas son:

1. `rol`
2. `usuario`
3. `mecanico`
4. `cliente`
5. `vehiculo`
6. `servicio`
7. `repuesto`
8. `historial_precio`
9. `orden_trabajo`
10. `historial_estado_orden`
11. `detalle_orden`
12. `factura`
13. `detalle_factura`
14. `pago`
15. `auditoria`

## 4. Propósito de cada tabla

| Tabla | Propósito |
|---|---|
| `rol` | Catálogo de roles de la aplicación. |
| `usuario` | Cuenta de acceso y datos básicos del usuario. |
| `mecanico` | Perfil técnico opcional y único de un usuario. |
| `cliente` | Persona natural o empresa propietaria de vehículos. |
| `vehiculo` | Vehículo asociado a un cliente. |
| `servicio` | Catálogo lógico de servicios, incluida la mano de obra. |
| `repuesto` | Catálogo de repuestos y existencias actuales. |
| `historial_precio` | Vigencias de costo y precio de un servicio o repuesto. |
| `orden_trabajo` | Cabecera y estado actual de una reparación. |
| `historial_estado_orden` | Bitácora inmutable de transiciones de una orden. |
| `detalle_orden` | Conceptos cobrables y precios congelados de la orden. |
| `factura` | Documento fiscal resumido generado desde una orden finalizada. |
| `detalle_factura` | Instantánea inmutable de los conceptos facturados. |
| `pago` | Registro y eventual anulación del pago total de una factura. |
| `auditoria` | Evidencia transversal de operaciones sensibles. |

## 5. Relaciones y cardinalidades

- `rol` 1:N `usuario`; cada usuario tiene exactamente un rol.
- `usuario` 1:0..1 `mecanico`; `mecanico.id_usuario` será único.
- `cliente` 1:N `vehiculo`; un vehículo tiene exactamente un propietario.
- `vehiculo` 1:N `orden_trabajo`.
- `mecanico` 1:N `orden_trabajo`; cada orden tiene un responsable.
- `usuario` 1:N `orden_trabajo` como usuario de apertura.
- `orden_trabajo` 1:N `historial_estado_orden`.
- `usuario` 1:N `historial_estado_orden` como autor del cambio.
- `servicio` 1:N `historial_precio` o `repuesto` 1:N
  `historial_precio`, con exclusión XOR: exactamente una de las dos FK.
- `usuario` 1:N `historial_precio` como creador de la vigencia.
- `orden_trabajo` 1:N `detalle_orden`.
- Cada `detalle_orden` corresponde a un `servicio` o a un `repuesto`, nunca a
  ambos, y referencia exactamente el `historial_precio` aplicado.
- `orden_trabajo` 1:0..1 `factura`.
- `factura` 1:N `detalle_factura`.
- `detalle_orden` 1:0..1 `detalle_factura`; evita facturar dos veces una misma
  línea.
- `factura` 1:N `pago` histórico, pero como máximo un pago no anulado.
- `usuario` se relaciona con los registros de pago y auditoría que genera.
- `auditoria` usa una referencia lógica (`tabla_afectada`, `id_registro`) para no
  crear FK polimórficas ni ciclos.

No existen ciclos de FK obligatorios. Las referencias avanzan desde catálogos y
maestros hacia documentos e históricos.

## 6. Orden recomendado de creación de tablas

1. `rol`
2. `usuario`
3. `mecanico`
4. `cliente`
5. `vehiculo`
6. `servicio`
7. `repuesto`
8. `historial_precio`
9. `orden_trabajo`
10. `historial_estado_orden`
11. `detalle_orden`
12. `factura`
13. `detalle_factura`
14. `pago`
15. `auditoria`

Este orden permite declarar las FK sin diferirlas ni deshabilitar integridad.

## 7. Eliminación lógica

`usuario`, `mecanico`, `cliente`, `vehiculo`, `servicio` y `repuesto` tendrán
`activo` y fecha de desactivación cuando sea relevante. `rol` también tendrá
`activo` para impedir nuevas asignaciones sin romper usuarios existentes.

La desactivación no borra relaciones históricas. Órdenes, precios usados,
facturas, detalles, pagos y auditorías no se eliminan físicamente. Una orden se
cancela por estado; una factura y un pago se anulan conservando el registro.

## 8. Estados

- Orden: `ingresada`, `diagnostico`, `esperando_repuestos`, `en_reparacion`,
  `finalizada`, `cancelada`.
- Factura: `emitida`, `anulada`. El estado de pagada no se almacena como verdad
  independiente: se deriva de un pago `registrado`.
- Pago: `registrado`, `anulado`.
- Disponibilidad de mecánico: `disponible`, `no_disponible`.
- Eliminación lógica: columna booleana `activo` (`1` activo, `0` inactivo).

Las transiciones de orden se detallan en `reglas_negocio.md`. La disponibilidad
manual del mecánico y su límite de órdenes activas se validarán conjuntamente.

## 9. Historial de precios

`historial_precio` tendrá `id_servicio` e `id_repuesto` opcionales y un `CHECK`
XOR que exige exactamente uno. Guardará costo base, precio de venta, inicio, fin
y usuario creador.

`fecha_fin IS NULL` identifica la única vigencia actual. Como una restricción
`UNIQUE` convencional de MySQL permite varios `NULL`, la unicidad vigente y la
ausencia de solapamientos se administrarán mediante un procedimiento
transaccional. Este bloqueará la fila del servicio o repuesto (`FOR UPDATE`),
cerrará la vigencia anterior e insertará la nueva. Un trigger defensivo impedirá
inserciones o actualizaciones que eludan esas reglas. Los precios utilizados
nunca se borrarán.

## 10. `detalle_orden`

Cada fila contendrá exactamente una FK de catálogo (`id_servicio` o
`id_repuesto`) y una FK obligatoria a `historial_precio`. Se almacenarán
`descripcion_concepto`, `cantidad`, `precio_unitario` y `subtotal` como
instantánea. El procedimiento de alta verificará que el precio histórico
corresponda al mismo concepto, esté vigente en el momento de alta y copiará su
precio de venta.

`subtotal` se almacena para congelar el importe y se validará al escribir como
`ROUND(cantidad * precio_unitario, 2)`. Los detalles dejan de modificarse al
finalizar o cancelar la orden.

## 11. `detalle_factura`

El diseño más sencillo con trazabilidad e inmutabilidad conserva:

- FK única a `detalle_orden`;
- FK a `factura`;
- tipo, código y descripción del concepto como texto congelado;
- cantidad, precio unitario y subtotal congelados.

No se repiten FK al catálogo ni al precio histórico porque la cadena
`detalle_factura -> detalle_orden -> historial_precio` ya conserva el origen, y
la instantánea textual protege al documento de cambios futuros del catálogo.

## 12. Inventario

`repuesto.stock_actual` y las cantidades usarán `DECIMAL(12,2)` para admitir
unidades fraccionables (por ejemplo, fluidos), siempre no negativas. Al finalizar
una orden, un procedimiento:

1. bloqueará la orden y los repuestos involucrados;
2. comprobará estado, disponibilidad de mecánico y existencias;
3. descontará la suma requerida por repuesto;
4. marcará `inventario_descontado = 1`;
5. cambiará el estado a `finalizada` y registrará el historial;
6. confirmará todo en una sola transacción.

El indicador y el bloqueo evitan el doble descuento. Cualquier error provoca
`ROLLBACK`.

## 13. Pagos

No hay pagos parciales. El procedimiento de registro bloqueará la factura,
comprobará que esté `emitida`, que no exista otro pago `registrado` y que el
monto sea exactamente igual al total. Una factura está pagada si existe un pago
relacionado con estado `registrado`.

Anular cambia el estado del pago, registra usuario, fecha y motivo, y mantiene
el historial. Tras una anulación podrá registrarse un nuevo pago total.

## 14. Distribución futura de mecanismos

### Restricciones declarativas

- PK, FK, `UNIQUE`, obligatoriedad y tipos compatibles.
- XOR servicio/repuesto en `historial_precio` y `detalle_orden`.
- Dominios de estados, valores monetarios no negativos, cantidad positiva.
- Identificación de cliente por tipo, longitud y caracteres numéricos.
- Placa, chasis informado, nombre de usuario, correo y números de documento
  únicos donde corresponda.
- Una factura por orden y un detalle de factura por detalle de orden.

### Procedimientos

- Registrar una nueva vigencia de precio con bloqueo.
- Agregar un detalle de orden y congelar el precio.
- Cambiar estado de orden y escribir su historial.
- Finalizar orden y descontar inventario una sola vez.
- Emitir factura y copiar todos sus detalles en una transacción.
- Registrar y anular pagos.
- Anular factura con sus validaciones.

### Triggers

- Defensa ante vigencias de precio solapadas o múltiples vigentes.
- Auditoría de cambios sensibles que puedan ocurrir fuera de procedimientos.
- Inmutabilidad de factura y sus detalles después de emitidos.
- Prevención defensiva de cambios directos incompatibles con estados terminales.

Los triggers no sustituirán la lógica transaccional principal.

### Vistas

- Catálogo de precios de venta vigentes sin `costo_base` para asesores.
- Estado de cobro de facturas derivado de pagos no anulados.
- Consultas de órdenes, totales y reportes sin exponer datos sensibles.

## 15. Riesgos y decisiones pendientes

1. **Numeración de factura:** falta confirmar formato, serie, establecimiento,
   punto de emisión y longitud exigidos por el contexto fiscal real. Se propone
   provisionalmente un correlativo textual generado bajo bloqueo.
2. **IVA:** se confirma 15 %, pero debe decidirse si el redondeo ocurre por línea
   o sobre el subtotal general. Se propone calcularlo sobre el subtotal general,
   con dos decimales.
3. **Unidades fraccionables:** se propone `DECIMAL(12,2)` para stock y cantidad.
   Debe validarse si todos los repuestos serán indivisibles; en ese caso podría
   usarse `INT UNSIGNED`.
4. **Datos personales obligatorios:** teléfono, correo y dirección quedan
   opcionales; el negocio debe confirmar los mínimos de contacto.
5. **Reasignación del propietario:** el modelo permite actualizar
   `vehiculo.id_cliente`, pero hacerlo alteraría la lectura histórica. Se propone
   prohibir la reasignación cuando existan órdenes y registrar otro vehículo si
   se requiere preservar propietarios históricos.
6. **Mecánico y rol:** la base exigirá que el perfil apunte a un usuario, pero
   verificar que ese usuario tenga rol `mecanico` requiere procedimiento o
   trigger porque un `CHECK` no consulta otra tabla.
7. **Edición de órdenes:** falta acordar qué campos pueden cambiar en cada
   estado; se propone bloquear sus detalles en estados terminales.
8. **Auditoría del actor:** el backend deberá establecer de forma confiable el
   usuario de aplicación para operaciones auditables.

## 16. Cambios o precisiones respecto del modelo conceptual

- Se incorpora una FK desde `detalle_orden` a `historial_precio`. No es una
  entidad nueva: resuelve la exigencia de identificar el precio aplicado y hace
  auditable la instantánea.
- Se añade `inventario_descontado` a `orden_trabajo` como guardia idempotente.
  Sin esta precisión, reintentar una finalización podría descontar dos veces.
- El estado pagado se deriva de `pago` y no se añade a `factura`, evitando dos
  fuentes de verdad.
- `detalle_factura` conserva instantáneas además de la referencia única al
  detalle de origen; esto garantiza trazabilidad e inmutabilidad.
- `auditoria` usa referencia lógica en lugar de muchas FK opcionales, evitando
  acoplamiento, columnas redundantes y ciclos.

## Mapa de implementación futura

| Archivo | Responsabilidad prevista |
|---|---|
| `02_tables.sql` | Crear las 15 tablas, columnas, PK y valores por defecto básicos. |
| `03_constraints.sql` | Agregar FK, `UNIQUE` y `CHECK` documentados. |
| `04_indexes.sql` | Crear solo índices candidatos confirmados que no estén cubiertos por PK o `UNIQUE`. |
| `05_views.sql` | Precios de venta vigentes, estado derivado de cobro y consultas seguras/reportes. |
| `06_procedures.sql` | Precios, detalles, estados, finalización, facturación y pagos transaccionales. |
| `07_triggers.sql` | Auditoría, defensas de integridad e inmutabilidad. |
| `08_seed_data.sql` | Datos ficticios: roles, usuarios, maestros, precios y escenarios reproducibles. |
| `09_test_queries.sql` | Casos válidos, inválidos, duplicados, estados prohibidos, concurrencia e integridad de `ROLLBACK`. |

