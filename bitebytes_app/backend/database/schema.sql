-- ============================================================
-- BiteBytes - Schema de Base de Datos
-- Ejecutar con: psql -U postgres -d bitebytes -f schema.sql
-- ============================================================

-- Extensión para UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ROLES Y USUARIOS
-- ============================================================

CREATE TABLE roles (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT
);

INSERT INTO roles (nombre, descripcion) VALUES
    ('super_admin',      'Acceso total al sistema'),
    ('admin',            'Gestión general del campus'),
    ('duenio_tienda',    'Propietario de una tienda'),
    ('trabajador_tienda','Empleado de una tienda'),
    ('alumno',           'Estudiante universitario'),
    ('visitante',        'Usuario no autenticado');

CREATE TABLE usuarios (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre          VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    foto_perfil     VARCHAR(500),
    rol_id          INTEGER NOT NULL REFERENCES roles(id),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TIENDAS
-- ============================================================

CREATE TABLE tipo_tienda (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    es_casino   BOOLEAN NOT NULL DEFAULT FALSE
);

INSERT INTO tipo_tienda (nombre, es_casino) VALUES
    ('tienda',  FALSE),
    ('casino',  TRUE),
    ('kiosco',  FALSE),
    ('cafeteria', FALSE);

CREATE TABLE tiendas (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre          VARCHAR(100) NOT NULL,
    descripcion     TEXT,
    latitud         DECIMAL(10, 8),
    longitud        DECIMAL(11, 8),
    horario         VARCHAR(200),
    imagen_url      VARCHAR(500),
    activa          BOOLEAN NOT NULL DEFAULT TRUE,
    duenio_id       UUID NOT NULL REFERENCES usuarios(id),
    tipo_tienda_id  INTEGER NOT NULL REFERENCES tipo_tienda(id),
    creado_en       TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE trabajadores_tienda (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tienda_id   UUID NOT NULL REFERENCES tiendas(id) ON DELETE CASCADE,
    desde       TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (usuario_id, tienda_id)
);

-- ============================================================
-- PRODUCTOS
-- ============================================================

CREATE TABLE categorias_producto (
    id      SERIAL PRIMARY KEY,
    nombre  VARCHAR(80) NOT NULL UNIQUE
);

INSERT INTO categorias_producto (nombre) VALUES
    ('Almuerzo'),
    ('Desayuno'),
    ('Bebidas'),
    ('Snacks'),
    ('Menú del día');

CREATE TABLE productos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tienda_id       UUID NOT NULL REFERENCES tiendas(id) ON DELETE CASCADE,
    categoria_id    INTEGER REFERENCES categorias_producto(id),
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    precio          DECIMAL(10, 2) NOT NULL CHECK (precio >= 0),
    imagen_url      VARCHAR(500),
    disponible      BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PUBLICACIONES (ofertas, promociones, menú del día)
-- ============================================================

CREATE TABLE publicaciones (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tienda_id       UUID NOT NULL REFERENCES tiendas(id) ON DELETE CASCADE,
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    precio_oferta   DECIMAL(10, 2),
    publicar_en     TIMESTAMP NOT NULL DEFAULT NOW(),
    expira_en       TIMESTAMP,
    activa          BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE publicacion_imagenes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publicacion_id  UUID NOT NULL REFERENCES publicaciones(id) ON DELETE CASCADE,
    imagen_url      VARCHAR(500) NOT NULL,
    orden           INTEGER NOT NULL DEFAULT 0
);

-- ============================================================
-- RESEÑAS Y CALIFICACIONES
-- ============================================================

CREATE TABLE resenias (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id      UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    producto_id     UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    calificacion    INTEGER NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario      TEXT,
    moderado        BOOLEAN NOT NULL DEFAULT FALSE,
    aprobado        BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (usuario_id, producto_id)
);

-- ============================================================
-- SANCIONES
-- ============================================================

CREATE TABLE sanciones (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    admin_id    UUID NOT NULL REFERENCES usuarios(id),
    motivo      TEXT NOT NULL,
    inicio      TIMESTAMP NOT NULL DEFAULT NOW(),
    fin         TIMESTAMP,
    activa      BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================
-- MENÚ DEL CASINO (tabla especial para el casino)
-- ============================================================

CREATE TABLE menu_casino (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tienda_id   UUID NOT NULL REFERENCES tiendas(id) ON DELETE CASCADE,
    fecha       DATE NOT NULL,
    entrada     VARCHAR(200),
    plato_fondo VARCHAR(200),
    postre      VARCHAR(200),
    vegetariano VARCHAR(200),
    precio      DECIMAL(10, 2),
    creado_en   TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (tienda_id, fecha)
);

-- ============================================================
-- ÍNDICES (mejoran velocidad de búsquedas frecuentes)
-- ============================================================

CREATE INDEX idx_productos_tienda     ON productos(tienda_id);
CREATE INDEX idx_publicaciones_tienda ON publicaciones(tienda_id);
CREATE INDEX idx_resenias_producto    ON resenias(producto_id);
CREATE INDEX idx_resenias_usuario     ON resenias(usuario_id);
CREATE INDEX idx_sanciones_usuario    ON sanciones(usuario_id);
CREATE INDEX idx_menu_casino_fecha    ON menu_casino(tienda_id, fecha);
CREATE INDEX idx_usuarios_email       ON usuarios(email);