-- Esquema de la base de datos del servicio web.
-- Ejecutar con:  mysql -u <usuario> -p < database/schema.sql
-- (el usuario necesita permiso para crear la base de datos; si ya la creaste, solo se crean las tablas)

CREATE DATABASE IF NOT EXISTS servicio_web;
USE servicio_web;

CREATE TABLE IF NOT EXISTS usuarios
(
    id_usuario       INTEGER AUTO_INCREMENT PRIMARY KEY,
    email            VARCHAR(100) NOT NULL,
    password         VARCHAR(64)  NOT NULL,   -- hash SHA-256 (hex) calculado en el cliente
    token            VARCHAR(20),             -- token de sesión generado en el login
    nombre           VARCHAR(100) NOT NULL,
    apellido_paterno VARCHAR(100) NOT NULL,
    apellido_materno VARCHAR(100),
    fecha_nacimiento DATETIME     NOT NULL,
    telefono         BIGINT,
    genero           CHAR(1),
    UNIQUE INDEX usuarios_1 (email)
);

CREATE TABLE IF NOT EXISTS fotos_usuarios
(
    id_foto    INTEGER AUTO_INCREMENT PRIMARY KEY,
    foto       LONGBLOB,
    id_usuario INTEGER NOT NULL,
    FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
);

-- Artículos en venta
CREATE TABLE IF NOT EXISTS stock
(
    id_articulo INTEGER AUTO_INCREMENT PRIMARY KEY,
    nombre      VARCHAR(100)  NOT NULL,
    descripcion VARCHAR(500),
    precio      DECIMAL(10,2) NOT NULL,
    cantidad    INTEGER       NOT NULL            -- existencias disponibles
);

CREATE TABLE IF NOT EXISTS fotos_articulos
(
    id_foto     INTEGER AUTO_INCREMENT PRIMARY KEY,
    fotografia  LONGBLOB,
    id_articulo INTEGER NOT NULL,
    FOREIGN KEY (id_articulo) REFERENCES stock (id_articulo)
);

-- Carrito de compra de cada usuario (un artículo no se repite dentro del carrito de un usuario)
CREATE TABLE IF NOT EXISTS carrito_compra
(
    id_usuario  INTEGER NOT NULL,
    id_articulo INTEGER NOT NULL,
    cantidad    INTEGER NOT NULL,
    UNIQUE INDEX carrito_compra_1 (id_usuario, id_articulo),
    FOREIGN KEY (id_usuario)  REFERENCES usuarios (id_usuario),
    FOREIGN KEY (id_articulo) REFERENCES stock (id_articulo)
);

-- Usuario de la aplicación (opcional; ejecutar como root, cambiar la contraseña y descomentar):
-- CREATE USER IF NOT EXISTS 'hugo' IDENTIFIED BY 'cambiar-contraseña';
-- GRANT ALL ON servicio_web.* TO 'hugo';
