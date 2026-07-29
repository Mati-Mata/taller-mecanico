# Sistema de Base de Datos para Taller Mecánico

Este repositorio implementa el modelo físico y el backend SQL de un sistema para
administrar las operaciones de un taller mecánico en MySQL 8.0. La base de datos
centraliza usuarios y roles, perfiles de mecánicos, clientes, vehículos,
servicios, repuestos, precios históricos, órdenes de trabajo, facturación,
pagos y auditoría.

## Alcance

El proyecto contiene actualmente la capa de base de datos: estructura,
integridad declarativa, consultas seguras, operaciones transaccionales,
validaciones defensivas, auditoría, datos demostrativos y pruebas.

El frontend y el backend web se desarrollarán posteriormente como una capa
separada. Este repositorio no incluye todavía una aplicación web, una API ni un
sistema de autenticación listo para producción.

## Características principales

- 15 tablas InnoDB con nombres en español y `snake_case`.
- 24 claves foráneas, 12 restricciones `UNIQUE` y 95 restricciones `CHECK`.
- 12 índices secundarios orientados a las consultas y operaciones críticas.
- 4 vistas de consulta.
- 11 procedimientos almacenados transaccionales.
- 40 triggers de defensa, inmutabilidad y auditoría.
- Historial de costos y precios con una única vigencia actual por concepto.
- Precios congelados en los detalles de órdenes y facturas.
- Descuento transaccional e idempotente de inventario al finalizar una orden.
- Facturación con IVA fijo del 15 %.
- Pagos completos; los pagos parciales no forman parte del alcance.
- Anulaciones lógicas de facturas y pagos, sin eliminar su historia.
- Auditoría con instantáneas JSON anteriores y nuevas.
- Datos semilla reproducibles y cinco escenarios operativos.
- Batería integral con invariantes, `EXPLAIN`, CRUD reversible y 15 rechazos.

## Tecnologías

- MySQL Server 8.0.
- MySQL Workbench 8.0.
- SQL.
- Git y GitHub.

## Requisitos

- MySQL Server 8.0 instalado y en ejecución.
- MySQL Workbench 8.0.
- Una cuenta MySQL con permisos para crear y eliminar la base
  `taller_mecanico`.
- El repositorio descargado o clonado.

## Estructura del proyecto

```text
taller-mecanico/
├── database/
│   ├── 00_run_all.sql
│   ├── 01_create_database.sql
│   ├── 02_tables.sql
│   ├── 03_constraints.sql
│   ├── 04_indexes.sql
│   ├── 05_views.sql
│   ├── 06_procedures.sql
│   ├── 07_triggers.sql
│   ├── 08_seed_data.sql
│   └── 09_test_queries.sql
├── docs/
│   ├── decisiones_modelo.md
│   ├── diccionario_datos.md
│   └── reglas_negocio.md
├── AGENTS.md
└── README.md
```

### Responsabilidad de los scripts

| Script | Responsabilidad |
|---|---|
| `00_run_all.sql` | Manifiesto portable con modos, orden e inspecciones de instalación. |
| `01_create_database.sql` | Reconstruye y selecciona la base `taller_mecanico`. |
| `02_tables.sql` | Crea las 15 tablas, columnas y claves primarias. |
| `03_constraints.sql` | Agrega claves foráneas, restricciones `UNIQUE` y `CHECK`. |
| `04_indexes.sql` | Crea los 12 índices secundarios justificados. |
| `05_views.sql` | Define las cuatro vistas representativas y seguras. |
| `06_procedures.sql` | Define los once procedimientos de negocio transaccionales. |
| `07_triggers.sql` | Instala defensas de integridad, inmutabilidad y auditoría. |
| `08_seed_data.sql` | Carga datos ficticios y escenarios reproducibles. |
| `09_test_queries.sql` | Ejecuta la batería integral y reversible de validación. |

La documentación de `docs/` explica las decisiones del modelo, el diccionario
de datos y las reglas de negocio.

## Instalación en MySQL Workbench

1. Inicie MySQL Server.
2. Abra MySQL Workbench.
3. Conéctese al servidor local con una cuenta autorizada.
4. Abra cada archivo con **File > Open SQL Script**.
5. Ejecute cada archivo completo en el orden numérico y espere a que termine.
6. Revise **Action Output** antes de continuar con el siguiente archivo.
7. Actualice el panel **Schemas**.
8. Compruebe que aparezca la base `taller_mecanico`.

Existen tres modos de instalación:

### Instalación limpia: estructura y backend SQL

Ejecute `01_create_database.sql` hasta `07_triggers.sql`.

El resultado es un esquema vacío, con restricciones, índices, vistas,
procedimientos y triggers, listo para integrarse con una aplicación.

### Demostración completa

Ejecute `01_create_database.sql` hasta `08_seed_data.sql`.

El resultado incluye el esquema completo, datos ficticios, cinco escenarios
operativos y sus eventos de auditoría.

### Pruebas completas

Ejecute `01_create_database.sql` hasta `09_test_queries.sql`.

`09_test_queries.sql` requiere que la semilla se haya cargado y debe ejecutarse
completo en la misma conexión de Workbench. Sus operaciones de prueba se
revierten para preservar los datos demostrativos.

## Advertencias importantes

> **Reconstrucción destructiva:** `01_create_database.sql` ejecuta
> `DROP DATABASE IF EXISTS` y elimina cualquier dato previo de
> `taller_mecanico`.

- `08_seed_data.sql` no es idempotente. No debe ejecutarse dos veces sobre la
  misma base.
- `09_test_queries.sql` requiere los datos de `08_seed_data.sql`.
- Si una fase falla, debe corregirse el problema y reconstruirse desde el
  archivo 01.
- No deben guardarse credenciales, contraseñas ni otros secretos reales en Git
  o GitHub.

## Datos de demostración

La semilla crea cuatro cuentas de aplicación:

- `admin_demo`
- `asesor_demo`
- `mecanico_uno`
- `mecanico_dos`

Los valores almacenados en `password_hash` son marcadores ficticios. No
representan contraseñas funcionales, no deben utilizarse en producción y no
permiten iniciar sesión. El futuro backend deberá generar hashes reales con
bcrypt o Argon2.

No se publican ni se inventan contraseñas para estas cuentas.

## Escenarios incluidos

1. Orden finalizada, facturada y pagada.
2. Factura emitida y pendiente de pago.
3. Orden activa esperando repuestos.
4. Orden cancelada antes del diagnóstico.
5. Factura anulada, conservando el descuento de inventario realizado al
   finalizar su orden.

## Vistas disponibles

| Vista | Finalidad |
|---|---|
| `vw_precios_venta_vigentes` | Expone precios de venta vigentes sin revelar el costo base. |
| `vw_historial_vehiculo` | Resume órdenes, vehículo, cliente, mecánico e importes estimados. |
| `vw_ordenes_mecanico` | Muestra asignaciones, carga activa y capacidad disponible por mecánico. |
| `vw_facturas_estado_cobro` | Deriva el número visible, estado de cobro, monto pagado y saldo. |

Las vistas usan `SQL SECURITY INVOKER`; el acceso efectivo dependerá de los
privilegios de la cuenta que las consulte.

## Procedimientos disponibles

| Procedimiento | Finalidad |
|---|---|
| `sp_crear_cliente_vehiculo` | Crea un cliente y su primer vehículo en una transacción. |
| `sp_registrar_precio` | Cierra la vigencia previa e inserta un nuevo precio. |
| `sp_crear_orden_trabajo` | Abre una orden, registra el estado inicial y actualiza kilometraje. |
| `sp_agregar_detalle_orden` | Agrega un servicio o repuesto con el precio vigente congelado. |
| `sp_actualizar_diagnostico_orden` | Actualiza diagnóstico y observación según el estado permitido. |
| `sp_cambiar_estado_orden` | Aplica una transición válida y registra su historial. |
| `sp_finalizar_orden` | Valida la orden, descuenta inventario y la finaliza atómicamente. |
| `sp_generar_factura` | Genera la factura y copia sus detalles desde una orden finalizada. |
| `sp_registrar_pago` | Registra el pago total de una factura emitida. |
| `sp_anular_pago` | Anula lógicamente un pago y conserva su trazabilidad. |
| `sp_anular_factura` | Anula una factura emitida sin pagos registrados. |

Las operaciones de escritura del futuro backend deben utilizar estos
procedimientos siempre que exista uno apropiado. El DML directo debe reservarse
para operaciones autorizadas que no tengan un procedimiento equivalente y
mantengan el contexto de auditoría.

## Auditoría

Los triggers registran, entre otras operaciones:

- altas y cambios sensibles de usuarios;
- rotación de contraseña sin almacenar el hash;
- cambios de roles, mecánicos, clientes, vehículos, servicios y repuestos;
- nuevas vigencias y cierres de precios;
- cambios operativos de órdenes;
- emisión y anulación de facturas;
- registro y anulación de pagos;
- movimientos de stock.

`auditoria.datos_anteriores` y `auditoria.datos_nuevos` almacenan instantáneas
JSON cuando corresponde. Los campos `origen` y `motivo` permiten identificar el
procedimiento o proceso responsable y justificar operaciones sensibles.

Los registros de auditoría están protegidos contra `UPDATE` y `DELETE`. Un
cambio de contraseña registra únicamente `password_hash_cambiado`; el valor de
`password_hash` nunca se copia a la auditoría.

## Pruebas

`09_test_queries.sql` comprueba:

- cantidades de objetos estructurales;
- cantidades y escenarios de los datos semilla;
- 16 invariantes que deben devolver cero filas;
- resultados de las cuatro vistas;
- planes de acceso con once consultas `EXPLAIN`;
- un CRUD transaccional reversible;
- 15 operaciones que deben ser rechazadas;
- ausencia de cambios permanentes y limpieza de objetos auxiliares.

El archivo genera muchas cuadrículas. MySQL Workbench puede mostrar:

```text
Maximum result count reached
```

Este mensaje no significa necesariamente que exista un error SQL. Puede indicar
que Workbench alcanzó su límite visual de pestañas de resultados. No cancele la
ejecución si continúa trabajando; revise **Action Output** y cierre pestañas de
resultados antes de repetir la batería.

El resultado esperado para las pruebas negativas es `PASS = 15` y `FAIL = 0`.

## Integración con un futuro backend web

Arquitectura recomendada:

```text
Navegador
    |
    | HTTP / JSON
    v
Backend Python
    |
    | Conector MySQL
    v
MySQL taller_mecanico
```

HTML y JavaScript no deben conectarse directamente a MySQL. El navegador debe
comunicarse por HTTP con un backend, y solamente el backend debe abrir
conexiones con la base.

El backend podrá implementarse posteriormente con Python. Flask y FastAPI son
opciones posibles, pero todavía no se selecciona una como definitiva. La capa
de backend deberá:

- validar y normalizar entradas;
- autenticar usuarios y autorizar operaciones;
- ejecutar los procedimientos almacenados apropiados;
- consultar las vistas;
- convertir los resultados a JSON;
- traducir errores SQL a respuestas seguras;
- manejar correctamente conexiones y transacciones;
- establecer el contexto de actor, origen y motivo para la auditoría.

Las credenciales de MySQL deben almacenarse en variables de entorno. Nunca deben
incluirse en JavaScript, archivos versionados o GitHub.

En desarrollo local se utilizarán normalmente:

| Parámetro | Valor orientativo |
|---|---|
| Host | `127.0.0.1` |
| Puerto | `3306` |
| Base | `taller_mecanico` |

El nombre de usuario y la contraseña MySQL dependerán de cada computadora y no
se incluyen en este repositorio.

## Usuario MySQL para la aplicación

El futuro backend debe utilizar una cuenta distinta de `root`, con privilegios
mínimos. La política concreta dependerá de la arquitectura, por lo que todavía
no se incluyen sentencias `GRANT` definitivas.

Como mínimo deberá evaluarse:

- lectura de las vistas necesarias;
- ejecución de los procedimientos autorizados;
- acceso directo a tablas específicas solo cuando sea indispensable.

La cuenta de aplicación no debería recibir `DROP`, `ALTER`, `TRUNCATE` ni
privilegios administrativos.

## Flujo de trabajo con Git

Cuando participe más de una persona:

1. Cree una rama para el cambio.
2. Modifique únicamente los archivos correspondientes.
3. Revise el diff y ejecute las pruebas aplicables.
4. Realice un commit descriptivo.
5. Publique la rama con `push` para revisión.

Nunca se deben versionar archivos que contengan contraseñas, claves privadas,
tokens u otros secretos.

## Demostración para la docente

Una exposición o video puede mostrar:

1. Ejecución ordenada de los scripts.
2. Las tablas y el diagrama del esquema.
3. Los datos semilla.
4. Las cuatro vistas.
5. El ciclo de una orden de trabajo.
6. La factura y su pago.
7. El descuento de inventario.
8. Los eventos de auditoría.
9. Una operación rechazada por integridad.
10. El resultado final de la batería de pruebas.

## Estado del proyecto

- Capa SQL terminada.
- Validada en MySQL Workbench 8.0 mediante la batería reproducible incluida.
- Preparada para integrarse con un backend web.
- Frontend y API pendientes.

No se han realizado pruebas de carga, seguridad ofensiva ni despliegue de
producción.

## Limitaciones

- Proyecto académico orientado a ejecución local.
- Hashes de contraseña exclusivamente demostrativos.
- Sin numeración tributaria oficial.
- Sin pagos parciales.
- Sin devolución automática de inventario al anular una factura.
- Sin frontend ni API incluidos.
- Requiere revisión adicional antes de cualquier uso en producción.

## Licencia o uso

Proyecto académico desarrollado con fines educativos.
