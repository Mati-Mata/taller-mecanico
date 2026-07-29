-- ============================================================================
-- SISTEMA DE BASE DE DATOS PARA TALLER MECÁNICO
-- Manifiesto portable de instalación para MySQL Workbench
-- Versión objetivo: MySQL Server 8.0
-- Base de datos: taller_mecanico
-- ============================================================================
--
-- Este archivo es una guía de ejecución. No instala objetos ni copia el
-- contenido de los demás scripts. Abra y ejecute cada archivo individualmente
-- desde MySQL Workbench, respetando el orden indicado.
--
-- ADVERTENCIA DE RECONSTRUCCIÓN
-- -----------------------------
-- 01_create_database.sql ejecuta DROP DATABASE IF EXISTS taller_mecanico.
-- Esto elimina completamente la base y todos sus datos. Ejecútelo únicamente
-- cuando desee realizar una instalación limpia o reconstruir el entorno.
--
-- ============================================================================
-- MODO A: SOLO ESTRUCTURA Y BACKEND SQL
-- ============================================================================
--
-- Ejecutar en este orden:
--
-- 1. 01_create_database.sql
-- 2. 02_tables.sql
-- 3. 03_constraints.sql
-- 4. 04_indexes.sql
-- 5. 05_views.sql
-- 6. 06_procedures.sql
-- 7. 07_triggers.sql
--
-- Resultado:
-- - esquema vacío;
-- - backend SQL completo;
-- - listo para ser utilizado por una aplicación;
-- - sin datos demostrativos.
--
-- ============================================================================
-- MODO B: DEMOSTRACIÓN COMPLETA
-- ============================================================================
--
-- Ejecutar los archivos 01 a 07 y después:
--
-- 8. 08_seed_data.sql
--
-- Resultado:
-- - esquema completo;
-- - datos reproducibles;
-- - clientes, vehículos, órdenes, facturas y pagos de demostración;
-- - auditoría automática.
--
-- ============================================================================
-- MODO C: VALIDACIÓN INTEGRAL
-- ============================================================================
--
-- Ejecutar los archivos 01 a 08 y después:
--
-- 9. 09_test_queries.sql
--
-- Resultado:
-- - comprobaciones estructurales;
-- - comprobaciones de invariantes;
-- - consultas de las vistas;
-- - planes EXPLAIN;
-- - CRUD reversible;
-- - 15 pruebas automáticas de rechazo;
-- - verificación de que la semilla no fue alterada.
--
-- ============================================================================
-- INSTRUCCIONES PARA MYSQL WORKBENCH
-- ============================================================================
--
-- 1. Inicie MySQL Server y abra una conexión local en MySQL Workbench.
-- 2. Abra cada archivo mediante File > Open SQL Script.
-- 3. Ejecute el archivo completo y espere a que termine antes de continuar.
-- 4. Revise Action Output después de cada archivo.
-- 5. No ejecute 08_seed_data.sql dos veces sobre la misma base.
-- 6. Ejecute siempre 09_test_queries.sql completo y en la misma conexión.
-- 7. Si una fase falla, corrija el problema y reconstruya desde el archivo 01.
--
-- 09_test_queries.sql produce numerosas cuadrículas de resultados. Workbench
-- puede mostrar el aviso:
--
-- Maximum result count reached
--
-- Este aviso no implica necesariamente un error SQL: puede indicar que se
-- alcanzó el límite visual de pestañas de resultados. No cancele la ejecución
-- si continúa trabajando. Revise Action Output y, antes de repetir las pruebas,
-- cierre pestañas de resultados que ya no necesite.
--
-- ============================================================================
-- RESULTADOS ESTRUCTURALES ESPERADOS
-- ============================================================================
--
-- +--------------------------------------+----------+
-- | Objeto                               | Cantidad |
-- +--------------------------------------+----------+
-- | Tablas base                          |       15 |
-- | Vistas                               |        4 |
-- | Procedimientos almacenados           |       11 |
-- | Triggers                             |       40 |
-- | Claves foráneas                      |       24 |
-- | Restricciones UNIQUE                 |       12 |
-- | Restricciones CHECK                  |       95 |
-- | Índices secundarios de Fase 3        |       12 |
-- +--------------------------------------+----------+
--
-- ============================================================================
-- DATOS SEMILLA ESPERADOS
-- ============================================================================
--
-- +----------------------+----------+
-- | Tabla o entidad      | Cantidad |
-- +----------------------+----------+
-- | Roles                |        3 |
-- | Usuarios             |        4 |
-- | Mecánicos            |        2 |
-- | Clientes             |        3 |
-- | Vehículos            |        3 |
-- | Servicios            |        5 |
-- | Repuestos            |        6 |
-- | Precios históricos   |       12 |
-- | Órdenes              |        5 |
-- | Detalles de orden    |        7 |
-- | Facturas             |        3 |
-- | Detalles de factura  |        5 |
-- | Pagos                |        1 |
-- | Auditorías           |       46 |
-- +----------------------+----------+
--
-- ============================================================================
-- CONSULTAS INFORMATIVAS Y NO DESTRUCTIVAS
-- Ejecutar solamente después de instalar los scripts correspondientes.
-- ============================================================================

SELECT DATABASE() AS base_seleccionada;
SELECT VERSION() AS version_mysql;

SELECT COUNT(*) AS tablas_base
FROM information_schema.tables
WHERE table_schema = 'taller_mecanico'
  AND table_type = 'BASE TABLE';

SELECT COUNT(*) AS vistas
FROM information_schema.views
WHERE table_schema = 'taller_mecanico';

SELECT COUNT(*) AS procedimientos
FROM information_schema.routines
WHERE routine_schema = 'taller_mecanico'
  AND routine_type = 'PROCEDURE';

SELECT COUNT(*) AS triggers
FROM information_schema.triggers
WHERE trigger_schema = 'taller_mecanico';
