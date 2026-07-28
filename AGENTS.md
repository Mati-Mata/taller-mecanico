# AGENTS.md

## 1. Propósito del proyecto

Este repositorio contiene el modelo físico y la implementación SQL en MySQL 8.0
de un sistema para administrar las operaciones de un taller mecánico.

El alcance actual está centrado exclusivamente en la base de datos.

No se debe generar frontend, backend web, API ni código Python, HTML, CSS o
JavaScript salvo que el usuario lo solicite expresamente en una fase posterior.

## 2. Entorno objetivo

- Motor: MySQL Server 8.0.
- Cliente principal de ejecución: MySQL Workbench 8.0.
- Motor de almacenamiento: InnoDB.
- Juego de caracteres: utf8mb4.
- Los scripts deben ser compatibles con MySQL 8.0.
- No utilizar sintaxis exclusiva de PostgreSQL, SQL Server, Oracle o SQLite.

## 3. Organización del repositorio

Los archivos de base de datos tienen responsabilidades separadas:

- `database/00_run_all.sql`: ejecuta los scripts en el orden correcto.
- `database/01_create_database.sql`: crea y selecciona la base de datos.
- `database/02_tables.sql`: crea las tablas.
- `database/03_constraints.sql`: agrega restricciones y claves foráneas.
- `database/04_indexes.sql`: crea índices justificados.
- `database/05_views.sql`: crea vistas.
- `database/06_procedures.sql`: crea procedimientos almacenados.
- `database/07_triggers.sql`: crea triggers.
- `database/08_seed_data.sql`: inserta datos ficticios de prueba.
- `database/09_test_queries.sql`: contiene pruebas y consultas de validación.

No mezclar responsabilidades entre archivos sin explicar previamente la razón.

## 4. Protocolo de trabajo por fases

El proyecto se implementa por fases.

Antes de modificar archivos:

1. Leer este archivo completo.
2. Revisar los archivos existentes.
3. Identificar la fase solicitada.
4. No implementar elementos de fases futuras.
5. No modificar archivos aprobados de fases anteriores salvo que sea necesario
   corregir un error demostrado.
6. Informar cualquier supuesto antes de convertirlo en una decisión irreversible.

Cuando se solicite una fase concreta, editar únicamente los archivos necesarios
para esa fase.

No generar todo el proyecto en una sola tarea.

## 5. Convenciones de nombres

- Usar español.
- Usar minúsculas.
- Usar `snake_case`.
- Usar nombres de tablas en singular.
- Claves primarias: `id_<tabla>`.
- Claves foráneas: conservar el mismo nombre que la clave referenciada.
- Evitar abreviaturas ambiguas.
- No usar palabras reservadas de MySQL como nombres de tablas o columnas.

Ejemplos correctos:

- `orden_trabajo`
- `detalle_orden`
- `id_cliente`
- `fecha_emision`

## 6. Convenciones de restricciones

Nombrar explícitamente las restricciones:

- Clave primaria: `pk_<tabla>`
- Clave foránea: `fk_<tabla>_<tabla_referenciada>`
- Valor único: `uq_<tabla>_<columnas>`
- Check: `ck_<tabla>_<regla>`

Usar `ON DELETE RESTRICT` como comportamiento predeterminado.

Usar `ON DELETE CASCADE` únicamente en entidades dependientes cuyo ciclo de vida
no tenga sentido sin el registro padre y siempre que no se pierda historial
financiero, operativo o de auditoría.

Preferir eliminación lógica mediante una columna de estado para clientes,
vehículos, usuarios, servicios y repuestos.

## 7. Tipos de datos

- Identificadores: `INT UNSIGNED AUTO_INCREMENT`, salvo justificación.
- Importes monetarios: `DECIMAL(12,2)`.
- No usar `FLOAT` ni `DOUBLE` para dinero.
- Fechas sin hora: `DATE`.
- Fechas con hora: `DATETIME`.
- Textos cortos: `VARCHAR` con longitud justificada.
- Descripciones largas: `TEXT` cuando corresponda.
- Contraseñas: almacenar únicamente `password_hash VARCHAR(255)`.
- No almacenar contraseñas en texto plano.

## 8. Reglas de dominio confirmadas

### Clientes

- Un cliente puede ser persona natural o empresa.
- La identificación debe aceptar cédulas ecuatorianas de 10 dígitos y RUC de
  13 dígitos.
- Utilizar una columna para el tipo de identificación y otra para el número.
- La identificación debe ser única.
- Validar longitud y que solo contenga dígitos.
- No implementar todavía validación matemática del dígito verificador.

### Vehículos

- Cada vehículo pertenece a un solo cliente.
- La placa debe ser única.
- El número de chasis debe ser único cuando esté informado.
- Los vehículos se desactivan de forma lógica; no se elimina su historial.

### Usuarios y roles

- Los roles principales son administrador, asesor y mecánico.
- Cada usuario de la aplicación tiene un solo rol.
- Un usuario puede tener un perfil de mecánico.
- Los permisos visuales serán controlados posteriormente por el backend.
- La base de datos debe almacenar la información necesaria para aplicar esos
  permisos.

### Órdenes de trabajo

- Cada orden corresponde a un solo vehículo.
- Cada orden tiene un solo mecánico responsable.
- Cada orden registra el usuario que la abrió.
- Una orden finalizada no puede regresar a un estado operativo anterior.
- Un nuevo problema posterior se registra como una nueva orden.
- Los cambios de estado se registran en `historial_estado_orden`.

### Detalle de orden

- Cada fila representa un solo concepto cobrable.
- Una fila contiene un servicio o un repuesto, pero nunca ambos.
- Tampoco se permite que ambos sean nulos.
- La cantidad debe ser mayor que cero.
- El precio vigente se congela al agregar el detalle.
- Los cambios futuros de precio no modifican los detalles existentes.

### Inventario

- No se permite stock negativo.
- No se puede finalizar una orden si no existe stock suficiente.
- El stock se descuenta al finalizar la orden.
- El descuento de stock debe ejecutarse una sola vez.

### Precios

- Servicios y repuestos tienen historial de precios.
- El historial almacena costo base y precio de venta.
- Solo debe existir un precio vigente por servicio o repuesto.
- Al registrar un nuevo precio se cierra la vigencia del precio anterior.
- Un precio utilizado por una orden o factura no se elimina físicamente.
- Los asesores solo podrán consultar precios de venta mediante una vista segura.

### Facturación

- Cada factura corresponde a una sola orden.
- Cada orden genera como máximo una factura.
- Solo se factura una orden finalizada.
- El IVA es del 15 %.
- Los valores se almacenan en dólares estadounidenses.
- El número de factura se genera automáticamente.
- Cada detalle de factura se origina en un detalle de orden.
- Los importes facturados conservan el precio congelado de la orden.

### Pagos

- No se permiten pagos parciales en el alcance actual.
- El pago debe cubrir el total pendiente de la factura.
- El estado pagado se determina mediante los pagos registrados.
- No se debe confiar exclusivamente en un estado ingresado manualmente.

### Auditoría

Auditar como mínimo:

- Cambios de precios.
- Cambios de estado de órdenes.
- Modificaciones o anulaciones de facturas.
- Registro o anulación de pagos.
- Desactivación de clientes y vehículos.
- Operaciones administrativas sensibles.

Cuando sea práctico, almacenar valores anteriores y nuevos como JSON.

## 9. Calidad del SQL

Todo script debe:

- Ejecutarse en MySQL 8.0.
- Terminar cada instrucción con `;`.
- Usar `DELIMITER` correctamente para procedimientos y triggers.
- Incluir comentarios útiles, sin comentar cada línea obvia.
- Evitar SQL dinámico salvo necesidad justificada.
- Evitar valores mágicos repetidos.
- Evitar tablas o columnas redundantes.
- Mantener integridad referencial.
- Evitar índices duplicados creados implícitamente por claves primarias o únicas.
- Utilizar transacciones en operaciones que modifiquen varias tablas.
- Incluir manejo de errores y `ROLLBACK` en procedimientos críticos.
- Utilizar bloqueos de fila cuando exista riesgo de doble facturación,
  doble descuento de stock o precios simultáneos.

## 10. Seguridad

- Nunca escribir contraseñas reales en el repositorio.
- Nunca incluir credenciales de conexión en archivos versionados.
- No conceder permisos globales de MySQL.
- No utilizar la cuenta `root` como usuario futuro del backend.
- No construir consultas futuras mediante concatenación de entradas del usuario.
- Los datos de prueba deben ser completamente ficticios.

## 11. Operaciones destructivas

- No usar `DROP DATABASE` fuera de `01_create_database.sql`.
- No borrar tablas o columnas aprobadas sin explicar el impacto.
- No realizar eliminaciones físicas sobre información financiera, histórica o de
  auditoría.
- No vaciar tablas mediante `TRUNCATE` dentro de procedimientos de negocio.
- Los scripts destructivos de reinicio deben estar claramente identificados.

## 12. Pruebas

Cada funcionalidad importante debe incluir:

- Un caso exitoso.
- Un caso con datos inválidos.
- Un caso duplicado cuando corresponda.
- Un caso con estado no permitido.
- Consultas `SELECT` que demuestren el resultado.
- Pruebas de que una transacción revierte completamente ante un error.

Los procedimientos y triggers no se consideran completos hasta que existan
consultas de prueba reproducibles.

## 13. Formato de respuesta de Codex

Después de cada tarea, indicar:

1. Archivos creados o modificados.
2. Resumen de los cambios.
3. Decisiones tomadas.
4. Supuestos pendientes.
5. Orden recomendado de ejecución.
6. Pruebas que el usuario debe ejecutar en MySQL Workbench.
7. Riesgos o limitaciones detectados.

No afirmar que el SQL funciona si no se ejecutó realmente.

Si Codex no tiene acceso a MySQL Server, debe indicar que solo realizó una revisión
estática y proporcionar las instrucciones de prueba para MySQL Workbench.