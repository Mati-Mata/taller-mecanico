-- Fase 1A: creación de la base de datos del taller mecánico.
-- ADVERTENCIA: este script elimina y reinicia completamente la base de datos.

DROP DATABASE IF EXISTS taller_mecanico;

CREATE DATABASE taller_mecanico
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE taller_mecanico;
