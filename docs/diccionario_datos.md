# Diccionario de datos propuesto

Los tipos son propuestas físicas para MySQL 8.0. `AUTO_INCREMENT` se aplicará a
todas las PK. Las expresiones de `CHECK` se describen, pero no se escribe SQL en
esta fase. Todas las FK tendrán tipos idénticos a sus PK: `INT UNSIGNED`.

## `rol`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_rol` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `nombre` | `VARCHAR(30)` | No | — | No | — | Sí | Valores iniciales: administrador, asesor, mecanico | Nombre funcional. |
| `descripcion` | `VARCHAR(255)` | Sí | `NULL` | No | — | No | — | Explicación del rol. |
| `activo` | `TINYINT UNSIGNED` | No | `1` | No | — | No | En (0, 1) | Permite nuevas asignaciones. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Alta del registro. |

- **Propósito:** catálogo de roles.
- **Claves candidatas:** `id_rol`, `nombre`.
- **Relaciones:** 1:N con `usuario`.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** ninguno adicional a PK y `UNIQUE(nombre)`.
- **Observaciones:** los tres nombres confirmados se cargarán como datos iniciales.

## `usuario`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_usuario` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_rol` | `INT UNSIGNED` | No | — | No | `rol.id_rol` | No | — | Rol asignado. |
| `cedula` | `VARCHAR(10)` | No | — | No | — | Sí | Exactamente 10 dígitos | Cédula del usuario. |
| `nombre_usuario` | `VARCHAR(60)` | No | — | No | — | Sí | Longitud mínima 3 | Identificador de acceso. |
| `password_hash` | `VARCHAR(255)` | No | — | No | — | No | No vacío | Hash de contraseña. |
| `nombres` | `VARCHAR(100)` | No | — | No | — | No | No vacío | Nombres personales. |
| `apellidos` | `VARCHAR(100)` | No | — | No | — | No | No vacío | Apellidos personales. |
| `correo` | `VARCHAR(254)` | No | — | No | — | Sí | Formato básico, validación completa en aplicación | Correo de la cuenta. |
| `telefono` | `VARCHAR(20)` | Sí | `NULL` | No | — | No | No vacío si se informa | Teléfono del usuario. |
| `activo` | `TINYINT UNSIGNED` | No | `1` | No | — | No | En (0, 1) | Habilitación lógica. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Alta de cuenta. |
| `fecha_actualizacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Última modificación. |
| `fecha_desactivacion` | `DATETIME` | Sí | `NULL` | No | — | No | Coherente con `activo` | Momento de desactivación. |

- **Propósito:** cuentas de la aplicación, no usuarios MySQL.
- **Claves candidatas:** `id_usuario`, `cedula`, `nombre_usuario`, `correo`.
- **Relaciones:** N:1 con `rol`; 1:0..1 con `mecanico`; autor de operaciones.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `id_rol, activo`.
- **Observaciones:** normalizar nombre de usuario y correo a minúsculas en la
  aplicación/procedimiento; no se valida matemáticamente el dígito verificador
  de la cédula; nunca almacenar contraseña plana.

## `mecanico`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_mecanico` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_usuario` | `INT UNSIGNED` | No | — | No | `usuario.id_usuario` | Sí | — | Cuenta vinculada 1:1. |
| `especialidad` | `VARCHAR(100)` | No | — | No | — | No | No vacía | Área técnica principal. |
| `nivel` | `VARCHAR(20)` | No | — | No | — | No | En (junior, intermedio, senior) | Nivel técnico propuesto. |
| `maximo_ordenes_activas` | `TINYINT UNSIGNED` | No | `3` | No | — | No | Mayor que cero | Capacidad simultánea. |
| `disponibilidad` | `VARCHAR(20)` | No | `disponible` | No | — | No | En (disponible, no_disponible) | Disponibilidad operativa. |
| `activo` | `TINYINT UNSIGNED` | No | `1` | No | — | No | En (0, 1) | Vigencia del perfil. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Alta del perfil. |
| `fecha_actualizacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Última modificación. |

- **Propósito:** extensión técnica opcional de un usuario.
- **Claves candidatas:** `id_mecanico`, `id_usuario`.
- **Relaciones:** N:1 con `usuario`; 1:N con `orden_trabajo`.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `activo, disponibilidad`.
- **Observaciones:** un procedimiento/trigger comprobará que el usuario tenga rol
  `mecanico`; el límite cuenta órdenes en estados no terminales.

## `cliente`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_cliente` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `tipo_cliente` | `VARCHAR(10)` | No | — | No | — | No | En (persona, empresa) | Naturaleza del cliente. |
| `tipo_identificacion` | `VARCHAR(10)` | No | — | No | — | No | En (cedula, ruc) | Tipo de documento. |
| `identificacion` | `VARCHAR(13)` | No | — | No | — | Sí | Solo dígitos; cédula 10, RUC 13 | Número de documento. |
| `nombres` | `VARCHAR(100)` | Sí | `NULL` | No | — | No | Obligatorio solo para persona | Nombres de persona. |
| `apellidos` | `VARCHAR(100)` | Sí | `NULL` | No | — | No | Obligatorio solo para persona | Apellidos de persona. |
| `razon_social` | `VARCHAR(150)` | Sí | `NULL` | No | — | No | Obligatoria solo para empresa | Nombre legal empresarial. |
| `telefono` | `VARCHAR(20)` | No | — | No | — | No | No vacío | Contacto telefónico obligatorio. |
| `correo` | `VARCHAR(254)` | Sí | `NULL` | No | — | No | Formato básico si se informa | Correo de contacto. |
| `direccion` | `VARCHAR(255)` | Sí | `NULL` | No | — | No | — | Dirección. |
| `activo` | `TINYINT UNSIGNED` | No | `1` | No | — | No | En (0, 1) | Eliminación lógica. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Alta. |
| `fecha_actualizacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Última modificación. |
| `fecha_desactivacion` | `DATETIME` | Sí | `NULL` | No | — | No | Coherente con `activo` | Desactivación. |

- **Propósito:** propietario natural o empresarial.
- **Claves candidatas:** `id_cliente`, `identificacion`.
- **Relaciones:** 1:N con `vehiculo`.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `activo`; `apellidos, nombres`; `razon_social`.
- **Observaciones:** no se valida todavía el dígito verificador.

## `vehiculo`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_vehiculo` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_cliente` | `INT UNSIGNED` | No | — | No | `cliente.id_cliente` | No | — | Propietario actual. |
| `placa` | `VARCHAR(10)` | No | — | No | — | Sí | No vacía | Placa normalizada. |
| `numero_chasis` | `VARCHAR(50)` | Sí | `NULL` | No | — | Sí | No vacío si se informa | VIN/chasis. |
| `marca` | `VARCHAR(60)` | No | — | No | — | No | No vacía | Marca. |
| `modelo` | `VARCHAR(60)` | No | — | No | — | No | No vacío | Modelo. |
| `anio` | `SMALLINT UNSIGNED` | Sí | `NULL` | No | — | No | Entre 1886 y 2100 | Año modelo. |
| `color` | `VARCHAR(40)` | Sí | `NULL` | No | — | No | — | Color. |
| `kilometraje_actual` | `INT UNSIGNED` | No | `0` | No | — | No | Mayor o igual a cero | Último kilometraje confirmado. |
| `activo` | `TINYINT UNSIGNED` | No | `1` | No | — | No | En (0, 1) | Eliminación lógica. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Alta. |
| `fecha_actualizacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Última modificación. |
| `fecha_desactivacion` | `DATETIME` | Sí | `NULL` | No | — | No | Coherente con `activo` | Desactivación. |

- **Propósito:** vehículos atendidos.
- **Claves candidatas:** `id_vehiculo`, `placa`, `numero_chasis` cuando se informa.
- **Relaciones:** N:1 con `cliente`; 1:N con `orden_trabajo`.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `id_cliente, activo`.
- **Observaciones:** placa y chasis se normalizan a mayúsculas; MySQL permite
  varios `NULL` en la restricción única de chasis. `id_cliente` puede corregirse
  solo mientras el vehículo no tenga órdenes; después queda inmutable. No se
  crea historial de propietarios.

## `servicio`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_servicio` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `codigo` | `VARCHAR(30)` | No | — | No | — | Sí | No vacío | Código comercial. |
| `nombre` | `VARCHAR(120)` | No | — | No | — | No | No vacío | Nombre del servicio. |
| `categoria` | `VARCHAR(60)` | Sí | `NULL` | No | — | No | No vacía si se informa | Clasificación libre del servicio. |
| `duracion_estimada_minutos` | `SMALLINT UNSIGNED` | Sí | `NULL` | No | — | No | Mayor que cero si se informa | Duración estimada. |
| `descripcion` | `TEXT` | Sí | `NULL` | No | — | No | — | Detalle funcional. |
| `activo` | `TINYINT UNSIGNED` | No | `1` | No | — | No | En (0, 1) | Disponibilidad lógica. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Alta. |
| `fecha_actualizacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Última modificación. |

- **Propósito:** catálogo de conceptos de servicio/mano de obra.
- **Claves candidatas:** `id_servicio`, `codigo`.
- **Relaciones:** 1:N con `historial_precio` y `detalle_orden`.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `activo, nombre`.
- **Observaciones:** desactivar no modifica precios ni órdenes anteriores.

## `repuesto`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_repuesto` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `codigo` | `VARCHAR(40)` | No | — | No | — | Sí | No vacío | Código interno/SKU. |
| `nombre` | `VARCHAR(120)` | No | — | No | — | No | No vacío | Nombre del repuesto. |
| `marca` | `VARCHAR(80)` | Sí | `NULL` | No | — | No | No vacía si se informa | Marca comercial. |
| `descripcion` | `TEXT` | Sí | `NULL` | No | — | No | — | Detalle. |
| `stock_actual` | `DECIMAL(12,2)` | No | `0.00` | No | — | No | Mayor o igual a cero | Existencia disponible. |
| `stock_minimo` | `DECIMAL(12,2)` | No | `0.00` | No | — | No | Mayor o igual a cero | Umbral informativo de reposición. |
| `unidad_medida` | `VARCHAR(20)` | No | — | No | — | No | No vacía | Unidad aplicable a stock y cantidades. |
| `activo` | `TINYINT UNSIGNED` | No | `1` | No | — | No | En (0, 1) | Disponibilidad lógica. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Alta. |
| `fecha_actualizacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Última modificación. |

- **Propósito:** catálogo e inventario actual de repuestos.
- **Claves candidatas:** `id_repuesto`, `codigo`.
- **Relaciones:** 1:N con `historial_precio` y `detalle_orden`.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `activo, nombre`.
- **Observaciones:** existencias y cantidades siguen en `DECIMAL(12,2)` para
  aceites, líquidos, mangueras u otros insumos fraccionables. La unidad de medida
  no tendrá lista cerrada todavía. El movimiento se infiere de
  finalizaciones/auditoría; no se añade una tabla de movimientos.

## `historial_precio`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_historial_precio` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_servicio` | `INT UNSIGNED` | Sí | `NULL` | No | `servicio.id_servicio` | No | XOR con `id_repuesto` | Servicio valorado. |
| `id_repuesto` | `INT UNSIGNED` | Sí | `NULL` | No | `repuesto.id_repuesto` | No | XOR con `id_servicio` | Repuesto valorado. |
| `costo_base` | `DECIMAL(12,2)` | No | — | No | — | No | Mayor o igual a cero | Costo interno. |
| `precio_venta` | `DECIMAL(12,2)` | No | — | No | — | No | Mayor o igual a costo base | Precio al cliente. |
| `fecha_inicio` | `DATETIME` | No | — | No | — | No | — | Inicio inclusivo. |
| `fecha_fin` | `DATETIME` | Sí | `NULL` | No | — | No | Mayor que `fecha_inicio` | Fin exclusivo; nulo vigente. |
| `id_usuario_creador` | `INT UNSIGNED` | No | — | No | `usuario.id_usuario` | No | — | Autor del cambio. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Registro técnico. |

- **Propósito:** historial inmutable de costos y precios.
- **Claves candidatas:** `id_historial_precio`.
- **Relaciones:** N:1 exclusiva con servicio/repuesto; N:1 con usuario; 1:N con
  `detalle_orden`.
- **ON DELETE / ON UPDATE:** todas `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `id_servicio, fecha_inicio, fecha_fin`;
  `id_repuesto, fecha_inicio, fecha_fin`; `id_usuario_creador`.
- **Observaciones:** la única vigencia y ausencia de solapamiento requieren
  procedimiento con bloqueo y trigger defensivo.

## `orden_trabajo`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_orden_trabajo` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_vehiculo` | `INT UNSIGNED` | No | — | No | `vehiculo.id_vehiculo` | No | — | Vehículo atendido. |
| `id_mecanico` | `INT UNSIGNED` | No | — | No | `mecanico.id_mecanico` | No | — | Responsable único. |
| `id_usuario_apertura` | `INT UNSIGNED` | No | — | No | `usuario.id_usuario` | No | — | Usuario que abrió. |
| `estado` | `VARCHAR(25)` | No | `ingresada` | No | — | No | Dominio de estados de orden | Estado actual. |
| `descripcion_problema` | `TEXT` | No | — | No | — | No | No vacía | Motivo de ingreso. |
| `diagnostico` | `TEXT` | Sí | `NULL` | No | — | No | — | Diagnóstico técnico. |
| `observacion` | `TEXT` | Sí | `NULL` | No | — | No | — | Notas generales. |
| `kilometraje_ingreso` | `INT UNSIGNED` | No | — | No | — | No | Mayor o igual al kilometraje actual al crear | Kilometraje recibido. |
| `inventario_descontado` | `TINYINT UNSIGNED` | No | `0` | No | — | No | En (0, 1); 1 solo si finalizada | Guardia idempotente. |
| `fecha_apertura` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Inicio. |
| `fecha_finalizacion` | `DATETIME` | Sí | `NULL` | No | — | No | Coherente con finalizada | Finalización. |
| `fecha_actualizacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Última modificación. |

- **Propósito:** ciclo operativo de reparación.
- **Claves candidatas:** `id_orden_trabajo`.
- **Relaciones:** N:1 con vehículo, mecánico y usuario; 1:N con historial y
  detalles; 1:0..1 con factura.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `id_vehiculo, fecha_apertura`;
  `id_mecanico, estado`; `estado, fecha_apertura`.
- **Observaciones:** crear la orden y actualizar
  `vehiculo.kilometraje_actual` será una sola transacción. Capacidad del
  mecánico, transición e inventario requieren procedimientos transaccionales.

## `historial_estado_orden`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_historial_estado_orden` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_orden_trabajo` | `INT UNSIGNED` | No | — | No | `orden_trabajo.id_orden_trabajo` | No | — | Orden afectada. |
| `estado_anterior` | `VARCHAR(25)` | Sí | `NULL` | No | — | No | Nulo solo en creación; dominio válido | Estado de origen. |
| `estado_nuevo` | `VARCHAR(25)` | No | — | No | — | No | Dominio válido y diferente del anterior | Estado de destino. |
| `id_usuario` | `INT UNSIGNED` | No | — | No | `usuario.id_usuario` | No | — | Autor. |
| `fecha_cambio` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Momento del cambio. |
| `observacion` | `VARCHAR(500)` | Sí | `NULL` | No | — | No | — | Motivo o nota. |

- **Propósito:** historial append-only de estados.
- **Claves candidatas:** `id_historial_estado_orden`.
- **Relaciones:** N:1 con orden y usuario.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `id_orden_trabajo, fecha_cambio`; `id_usuario`.
- **Observaciones:** la fila inicial tendrá anterior nulo y nuevo `ingresada`.

## `detalle_orden`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_detalle_orden` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_orden_trabajo` | `INT UNSIGNED` | No | — | No | `orden_trabajo.id_orden_trabajo` | No | — | Orden. |
| `id_servicio` | `INT UNSIGNED` | Sí | `NULL` | No | `servicio.id_servicio` | No | XOR con repuesto | Servicio. |
| `id_repuesto` | `INT UNSIGNED` | Sí | `NULL` | No | `repuesto.id_repuesto` | No | XOR con servicio | Repuesto. |
| `id_historial_precio` | `INT UNSIGNED` | No | — | No | `historial_precio.id_historial_precio` | No | Debe corresponder al concepto | Precio de origen. |
| `descripcion_concepto` | `VARCHAR(255)` | No | — | No | — | No | No vacía | Nombre congelado. |
| `cantidad` | `DECIMAL(12,2)` | No | — | No | — | No | Mayor que cero | Cantidad cobrada. |
| `precio_unitario` | `DECIMAL(12,2)` | No | — | No | — | No | Mayor o igual a cero | Precio congelado. |
| `subtotal` | `DECIMAL(12,2)` | No | — | No | — | No | Igual a cantidad por precio, redondeado | Importe congelado. |
| `observacion` | `VARCHAR(500)` | Sí | `NULL` | No | — | No | — | Nota específica de la línea. |
| `fecha_creacion` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Alta del detalle. |

- **Propósito:** conceptos cobrables de una orden.
- **Claves candidatas:** `id_detalle_orden`.
- **Relaciones:** N:1 con orden, catálogo exclusivo y precio; 1:0..1 con detalle
  de factura.
- **ON DELETE / ON UPDATE:** todas `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `id_orden_trabajo`; `id_servicio`;
  `id_repuesto`; `id_historial_precio`.
- **Observaciones:** la correspondencia concepto-precio y la copia segura se
  validan en procedimiento; inmutable al llegar a estado terminal.

## `factura`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_factura` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_orden_trabajo` | `INT UNSIGNED` | No | — | No | `orden_trabajo.id_orden_trabajo` | Sí | — | Orden facturada una vez. |
| `estado` | `VARCHAR(10)` | No | `emitida` | No | — | No | En (emitida, anulada) | Estado documental. |
| `fecha_emision` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Emisión. |
| `identificacion_cliente` | `VARCHAR(13)` | No | — | No | — | No | 10 o 13 dígitos según cliente de origen | Identificación congelada. |
| `nombre_cliente` | `VARCHAR(200)` | No | — | No | — | No | No vacío | Nombre o razón social congelados. |
| `direccion_cliente` | `VARCHAR(255)` | Sí | `NULL` | No | — | No | — | Dirección congelada. |
| `placa_vehiculo` | `VARCHAR(10)` | No | — | No | — | No | No vacía | Placa congelada. |
| `subtotal` | `DECIMAL(12,2)` | No | — | No | — | No | Mayor o igual a cero | Suma antes de IVA. |
| `porcentaje_iva` | `DECIMAL(5,2)` | No | `15.00` | No | — | No | Entre 0 y 100 | Tasa congelada. |
| `valor_iva` | `DECIMAL(12,2)` | No | — | No | — | No | Igual al cálculo redondeado | IVA. |
| `total` | `DECIMAL(12,2)` | No | — | No | — | No | Igual a subtotal más IVA | Total. |
| `id_usuario_emision` | `INT UNSIGNED` | No | — | No | `usuario.id_usuario` | No | — | Emisor. |
| `fecha_anulacion` | `DATETIME` | Sí | `NULL` | No | — | No | Coherente con anulada | Momento de anulación. |
| `id_usuario_anulacion` | `INT UNSIGNED` | Sí | `NULL` | No | `usuario.id_usuario` | No | Coherente con anulada | Usuario que anuló. |
| `motivo_anulacion` | `VARCHAR(500)` | Sí | `NULL` | No | — | No | Obligatorio al anular | Justificación. |

- **Propósito:** cabecera fiscal inmutable de una orden finalizada.
- **Claves candidatas:** `id_factura`, `id_orden_trabajo`.
- **Relaciones:** N:1 con orden y usuarios; 1:N con detalles y pagos.
- **ON DELETE / ON UPDATE:** todas `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `estado, fecha_emision`; FK de usuarios si las
  consultas lo justifican.
- **Observaciones:** identificación, nombre, dirección y placa se copian al
  emitir y quedan inmutables. El número visible no se almacena: una vista futura
  lo derivará de `id_factura` con formato `FAC-00000001`. El pago se deriva, no
  se almacena como estado.

## `detalle_factura`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_detalle_factura` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_factura` | `INT UNSIGNED` | No | — | No | `factura.id_factura` | No | — | Cabecera. |
| `id_detalle_orden` | `INT UNSIGNED` | No | — | No | `detalle_orden.id_detalle_orden` | Sí | — | Línea de origen única. |
| `tipo_concepto` | `VARCHAR(10)` | No | — | No | — | No | En (servicio, repuesto) | Tipo congelado. |
| `codigo_concepto` | `VARCHAR(40)` | No | — | No | — | No | No vacío | Código congelado. |
| `descripcion_concepto` | `VARCHAR(255)` | No | — | No | — | No | No vacía | Descripción congelada. |
| `cantidad` | `DECIMAL(12,2)` | No | — | No | — | No | Mayor que cero | Cantidad congelada. |
| `precio_unitario` | `DECIMAL(12,2)` | No | — | No | — | No | Mayor o igual a cero | Precio congelado. |
| `subtotal` | `DECIMAL(12,2)` | No | — | No | — | No | Igual a cantidad por precio, redondeado | Subtotal congelado. |

- **Propósito:** instantánea de líneas facturadas.
- **Claves candidatas:** `id_detalle_factura`, `id_detalle_orden`.
- **Relaciones:** N:1 con factura; 1:1 opcional desde detalle de orden.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `id_factura`; el `UNIQUE(id_detalle_orden)` cubre origen.
- **Observaciones:** no se edita ni elimina después de emisión.

## `pago`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_pago` | `INT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador. |
| `id_factura` | `INT UNSIGNED` | No | — | No | `factura.id_factura` | No | — | Factura cubierta. |
| `monto` | `DECIMAL(12,2)` | No | — | No | — | No | Mayor que cero | Pago total. |
| `metodo_pago` | `VARCHAR(20)` | No | — | No | — | No | En (efectivo, tarjeta, transferencia) | Medio propuesto. |
| `referencia` | `VARCHAR(100)` | Sí | `NULL` | No | — | No | Requerida para transferencia/tarjeta | Referencia externa. |
| `estado` | `VARCHAR(10)` | No | `registrado` | No | — | No | En (registrado, anulado) | Estado del pago. |
| `fecha_pago` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Registro del cobro. |
| `id_usuario_registro` | `INT UNSIGNED` | No | — | No | `usuario.id_usuario` | No | — | Usuario registrador. |
| `fecha_anulacion` | `DATETIME` | Sí | `NULL` | No | — | No | Coherente con anulado | Anulación. |
| `id_usuario_anulacion` | `INT UNSIGNED` | Sí | `NULL` | No | `usuario.id_usuario` | No | Coherente con anulado | Usuario que anuló. |
| `motivo_anulacion` | `VARCHAR(500)` | Sí | `NULL` | No | — | No | Obligatorio al anular | Motivo. |

- **Propósito:** cobro total y su historial de anulación.
- **Claves candidatas:** `id_pago`.
- **Relaciones:** N:1 con factura y usuarios.
- **ON DELETE / ON UPDATE:** `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `id_factura, estado`; `fecha_pago`;
  FK de usuarios si las consultas lo justifican.
- **Observaciones:** como máximo uno `registrado` por factura, garantizado por
  procedimiento con bloqueo y trigger defensivo.

## `auditoria`

| Columna | Tipo MySQL | NULL | Predeterminado | PK | FK | Único | CHECK previsto | Descripción |
|---|---|---:|---|---:|---|---:|---|---|
| `id_auditoria` | `BIGINT UNSIGNED` | No | Autonumérico | Sí | — | Sí | Mayor que cero | Identificador de alto volumen. |
| `id_usuario` | `INT UNSIGNED` | Sí | `NULL` | No | `usuario.id_usuario` | No | — | Actor, nulo solo para proceso técnico identificable. |
| `tabla_afectada` | `VARCHAR(64)` | No | — | No | — | No | No vacía | Tabla lógica afectada. |
| `id_registro` | `BIGINT UNSIGNED` | No | — | No | — | No | Mayor que cero | ID lógico afectado. |
| `accion` | `VARCHAR(30)` | No | — | No | — | No | Dominio de acciones auditables | Tipo de operación. |
| `motivo` | `VARCHAR(500)` | Sí | `NULL` | No | — | No | — | Justificación de desactivación, anulación u operación sensible. |
| `datos_anteriores` | `JSON` | Sí | `NULL` | No | — | No | JSON válido por tipo | Imagen anterior. |
| `datos_nuevos` | `JSON` | Sí | `NULL` | No | — | No | JSON válido por tipo | Imagen nueva. |
| `fecha_evento` | `DATETIME` | No | Fecha/hora actual | No | — | No | — | Momento. |
| `origen` | `VARCHAR(50)` | Sí | `NULL` | No | — | No | — | Procedimiento, backend o sesión. |
| `direccion_ip` | `VARCHAR(45)` | Sí | `NULL` | No | — | No | — | IPv4/IPv6 si el backend la aporta. |

- **Propósito:** evidencia transversal append-only.
- **Claves candidatas:** `id_auditoria`.
- **Relaciones:** N:1 opcional con usuario; referencia lógica al registro
  afectado.
- **ON DELETE / ON UPDATE:** usuario `RESTRICT` / `RESTRICT`.
- **Índices candidatos:** `tabla_afectada, id_registro, fecha_evento`;
  `id_usuario, fecha_evento`; `accion, fecha_evento`.
- **Observaciones:** no hay FK polimórfica; `id_registro` es `BIGINT` para aceptar
  PK `INT` y `BIGINT`. La tabla no se actualiza ni elimina por lógica de negocio.
