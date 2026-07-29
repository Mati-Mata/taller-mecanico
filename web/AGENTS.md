# AGENTS.md — Aplicación web

Estas instrucciones aplican a todo el contenido dentro de `web/`.

1. No modificar `database/` sin autorización explícita del usuario.
2. No duplicar en Python reglas ya implementadas en procedimientos o triggers.
3. Usar procedimientos almacenados para las operaciones de negocio disponibles.
4. Usar las vistas SQL para consultas cuando sean apropiadas.
5. Usar siempre consultas parametrizadas.
6. No guardar secretos, credenciales ni contraseñas en el repositorio.
7. Mantener el diseño oscuro, industrial, legible y responsive.
8. Mantener Flask, Jinja y JavaScript nativo como stack de la aplicación.
9. No agregar React, Node.js, un ORM ni herramientas de compilación frontend.
10. Aplicar permisos tanto en la interfaz como en las rutas del servidor.
11. Crear commits pequeños, descriptivos y limitados a una responsabilidad.
12. Priorizar la simplicidad y la ejecución local reproducible.
