# Aplicación web local del Taller Mecánico

Aplicación Flask para operar la base `taller_mecanico`: autenticación,
clientes y vehículos, órdenes de trabajo, facturación y pagos.

## Requisitos

- Windows con Python 3.10 o posterior.
- MySQL Server 8.0 en ejecución.
- MySQL Workbench para instalar la base.
- Conexión a internet para cargar Bootstrap y Bootstrap Icons desde CDN.

## Preparación en Windows

1. Abra PowerShell o una terminal.
2. Entre en la carpeta `web/`.
3. Cree el entorno virtual:

   ```powershell
   py -m venv .venv
   ```

4. Actívelo:

   ```powershell
   .\.venv\Scripts\activate
   ```

5. Instale las dependencias:

   ```powershell
   pip install -r requirements.txt
   ```

6. Cree la configuración local:

   ```powershell
   copy .env.example .env
   ```

7. Edite `.env` y configure `MYSQL_USER`, `MYSQL_PASSWORD` y un valor aleatorio
   para `FLASK_SECRET_KEY`.
8. En MySQL Workbench, ejecute los scripts `database/01_create_database.sql`
   hasta `database/08_seed_data.sql`.
9. Configure la contraseña local del administrador:

   ```powershell
   python set_demo_password.py
   ```

10. Escriba dos veces una contraseña de al menos ocho caracteres. No aparecerá
    en pantalla ni se guardará en archivos.
11. Inicie la aplicación:

    ```powershell
    python run.py
    ```

12. Abra [http://127.0.0.1:5000](http://127.0.0.1:5000).
13. Compruebe la conexión en
    [http://127.0.0.1:5000/health](http://127.0.0.1:5000/health).

El acceso demostrativo utiliza el usuario `admin_demo` y la contraseña elegida
localmente con `set_demo_password.py`.

## Rutas disponibles

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/` | Redirige al login o al dashboard según la sesión. |
| `GET` | `/health` | Comprueba la conexión con MySQL y devuelve JSON. |
| `GET`, `POST` | `/login` | Presenta y procesa el inicio de sesión. |
| `POST` | `/logout` | Cierra la sesión actual. |
| `GET` | `/dashboard` | Muestra el panel privado con datos reales. |
| `GET` | `/clientes` | Busca y lista clientes. |
| `GET`, `POST` | `/clientes/nuevo` | Crea un cliente y su primer vehículo. |
| `GET` | `/clientes/<id>` | Muestra ficha, vehículos e historial. |
| `GET` | `/vehiculos/<id>` | Muestra el historial del vehículo. |
| `GET` | `/ordenes` | Lista las órdenes autorizadas. |
| `GET`, `POST` | `/ordenes/nueva` | Abre una orden de trabajo. |
| `GET` | `/ordenes/<id>` | Gestiona diagnóstico, detalles y estado. |
| `POST` | `/ordenes/<id>/finalizar` | Finaliza la orden y descuenta inventario. |
| `GET` | `/facturas` | Lista facturas y su estado de cobro. |
| `GET` | `/facturas/<id>` | Muestra el comprobante, detalles y pagos. |
| `POST` | `/ordenes/<id>/generar-factura` | Genera la factura de una orden finalizada. |
| `POST` | `/facturas/<id>/registrar-pago` | Registra el pago total pendiente. |
| `POST` | `/facturas/<id>/anular` | Anula una factura (administrador). |
| `POST` | `/pagos/<id>/anular` | Anula un pago (administrador). |

Las anulaciones de facturas y pagos están disponibles únicamente para el rol
`administrador`.

## Perfiles y permisos

- `administrador`: acceso operativo completo y anulaciones.
- `asesor`: clientes, vehículos, órdenes, facturación y registro de pagos; no
  puede anular.
- `mecanico`: únicamente sus órdenes asignadas; puede registrar diagnóstico,
  conceptos, cambios de estado y finalización. No accede a clientes ni facturas.

Los permisos se aplican en las rutas del servidor y también ocultan las
acciones no autorizadas en la interfaz.

## Operaciones de escritura

La aplicación no duplica la lógica de negocio de MySQL. Los formularios llaman
exclusivamente a los procedimientos almacenados aprobados:

- `sp_crear_cliente_vehiculo`
- `sp_crear_orden_trabajo`
- `sp_actualizar_diagnostico_orden`
- `sp_agregar_detalle_orden`
- `sp_cambiar_estado_orden`
- `sp_finalizar_orden`
- `sp_generar_factura`
- `sp_registrar_pago`
- `sp_anular_factura`
- `sp_anular_pago`

Los mensajes lanzados por MySQL con `SIGNAL SQLSTATE '45000'` se presentan como
errores de negocio. Otros errores se mantienen genéricos para no exponer datos
internos.

## Configuración

La aplicación lee exclusivamente variables del archivo local `.env`. Este
archivo está excluido de Git.

- `FLASK_HOST` usa `127.0.0.1` de forma predeterminada.
- `FLASK_DEBUG` controla el modo de depuración.
- `MYSQL_DATABASE` debe conservar el valor `taller_mecanico`.
- No incluya secretos en `.env.example`.

## Pruebas

Con el entorno activo:

```powershell
pytest
```

Las pruebas de humo importan la fábrica, abren el login, comprueban que las
rutas operativas exigen autenticación, validan la matriz visible de estados y
la página 404 sin conectarse a MySQL.

Para una prueba funcional completa con los datos semilla:

1. Inicie sesión como administrador y cree un cliente con vehículo.
2. Abra una orden, registre diagnóstico y agregue conceptos.
3. Recorra los estados permitidos hasta `en_reparacion` y finalice la orden.
4. Genere la factura y registre el pago total pendiente.
5. Compruebe el comprobante imprimible y los cambios en el dashboard.
6. Repita la navegación con asesor y mecánico para verificar sus límites.

## Flujo de demostración de cinco minutos

1. Inicie sesión como administrador.
2. Presente los indicadores del dashboard.
3. Consulte la lista y la ficha de un cliente.
4. Abra una orden existente.
5. Muestre sus conceptos y el historial de estados.
6. Abra una factura pagada para enseñar el comprobante y sus pagos.
7. Abra una factura pendiente para mostrar el saldo y el formulario de cobro.
8. Regrese al dashboard y señale el inventario reflejado.

No se necesita exponer ninguna contraseña durante la grabación.

## Solución de problemas

### Access denied for user

Revise `MYSQL_USER` y `MYSQL_PASSWORD` en `.env`. Confirme que la cuenta tenga
acceso local a `taller_mecanico`.

### Can't connect to MySQL server

Compruebe que MySQL Server esté iniciado y que `MYSQL_HOST` y `MYSQL_PORT`
coincidan con la instalación local.

### Unknown database taller_mecanico

Ejecute en Workbench los scripts desde `database/01_create_database.sql` hasta
`database/08_seed_data.sql`.

### Credenciales incorrectas en el login

Ejecute nuevamente `python set_demo_password.py` y use `admin_demo` con la
contraseña que acaba de elegir.

### Bootstrap aparece sin estilos

Bootstrap se carga mediante CDN y necesita conexión a internet. Para una
demostración completamente offline, sus recursos pueden descargarse y servirse
localmente en una fase posterior.

## Alcance actual

Este MVP cubre el flujo operativo completo solicitado. La gestión general de
catálogos, precios, usuarios y permisos granulares queda fuera de esta fase.
Está pensado para ejecución local, requiere MySQL ya instalado y usa CDN para
Bootstrap. No incluye paginación avanzada, protección CSRF, PDF, correo,
archivos adjuntos ni despliegue público.
