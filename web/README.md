# Aplicación web local del Taller Mecánico

Aplicación Flask para consultar la base `taller_mecanico`, autenticar usuarios
de la tabla `usuario` y mostrar un dashboard operativo con datos reales.

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

Las pruebas de humo importan la fábrica, abren el login, comprueban la
protección del dashboard y validan la página 404 sin conectarse a MySQL.

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

Esta fase incluye conexión, salud, autenticación, autorización preparada por
roles y dashboard. Los módulos de clientes, órdenes y facturación aparecen como
próximas funciones y todavía no implementan operaciones.
