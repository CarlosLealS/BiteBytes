-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.roles (
  id integer NOT NULL DEFAULT nextval('roles_id_seq'::regclass),
  nombre character varying NOT NULL UNIQUE,
  descripcion text,
  CONSTRAINT roles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.usuarios (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nombre character varying NOT NULL,
  email character varying NOT NULL UNIQUE,
  password_hash character varying NOT NULL,
  foto_perfil character varying,
  rol_id integer NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT usuarios_pkey PRIMARY KEY (id),
  CONSTRAINT usuarios_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id)
);
CREATE TABLE public.tipo_tienda (
  id integer NOT NULL DEFAULT nextval('tipo_tienda_id_seq'::regclass),
  nombre character varying NOT NULL UNIQUE,
  es_casino boolean NOT NULL DEFAULT false,
  CONSTRAINT tipo_tienda_pkey PRIMARY KEY (id)
);
CREATE TABLE public.tiendas (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nombre character varying NOT NULL,
  descripcion text,
  latitud numeric,
  longitud numeric,
  horario character varying,
  imagen_url character varying,
  activa boolean NOT NULL DEFAULT true,
  duenio_id uuid NOT NULL,
  tipo_tienda_id integer NOT NULL,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT tiendas_pkey PRIMARY KEY (id),
  CONSTRAINT tiendas_duenio_id_fkey FOREIGN KEY (duenio_id) REFERENCES public.usuarios(id),
  CONSTRAINT tiendas_tipo_tienda_id_fkey FOREIGN KEY (tipo_tienda_id) REFERENCES public.tipo_tienda(id)
);
CREATE TABLE public.trabajadores_tienda (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  tienda_id uuid NOT NULL,
  desde timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT trabajadores_tienda_pkey PRIMARY KEY (id),
  CONSTRAINT trabajadores_tienda_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id),
  CONSTRAINT trabajadores_tienda_tienda_id_fkey FOREIGN KEY (tienda_id) REFERENCES public.tiendas(id)
);
CREATE TABLE public.categorias_producto (
  id integer NOT NULL DEFAULT nextval('categorias_producto_id_seq'::regclass),
  nombre character varying NOT NULL UNIQUE,
  CONSTRAINT categorias_producto_pkey PRIMARY KEY (id)
);
CREATE TABLE public.productos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tienda_id uuid NOT NULL,
  categoria_id integer,
  nombre character varying NOT NULL,
  descripcion text,
  precio integer NOT NULL CHECK (precio::numeric >= 0::numeric),
  imagen_url character varying,
  disponible boolean NOT NULL DEFAULT true,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp without time zone NOT NULL DEFAULT now(),
  imagen_public_id text,
  CONSTRAINT productos_pkey PRIMARY KEY (id),
  CONSTRAINT productos_tienda_id_fkey FOREIGN KEY (tienda_id) REFERENCES public.tiendas(id),
  CONSTRAINT productos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias_producto(id)
);
CREATE TABLE public.publicaciones (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tienda_id uuid NOT NULL,
  nombre character varying NOT NULL,
  descripcion text,
  precio_oferta integer,
  publicar_en timestamp without time zone NOT NULL DEFAULT now(),
  expira_en timestamp without time zone,
  activa boolean NOT NULL DEFAULT true,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp without time zone NOT NULL DEFAULT now(),
  imagen_public_id text,
  CONSTRAINT publicaciones_pkey PRIMARY KEY (id),
  CONSTRAINT publicaciones_tienda_id_fkey FOREIGN KEY (tienda_id) REFERENCES public.tiendas(id)
);
CREATE TABLE public.publicacion_imagenes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  publicacion_id uuid NOT NULL,
  imagen_url character varying NOT NULL,
  orden integer NOT NULL DEFAULT 0,
  imagen_public_id text,
  CONSTRAINT publicacion_imagenes_pkey PRIMARY KEY (id),
  CONSTRAINT publicacion_imagenes_publicacion_id_fkey FOREIGN KEY (publicacion_id) REFERENCES public.publicaciones(id)
);
CREATE TABLE public.resenias (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  producto_id uuid NOT NULL,
  calificacion integer NOT NULL CHECK (calificacion >= 1 AND calificacion <= 5),
  comentario text,
  moderado boolean NOT NULL DEFAULT false,
  aprobado boolean NOT NULL DEFAULT true,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT resenias_pkey PRIMARY KEY (id),
  CONSTRAINT resenias_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id),
  CONSTRAINT resenias_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id)
);
CREATE TABLE public.sanciones (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  admin_id uuid NOT NULL,
  motivo text NOT NULL,
  inicio timestamp without time zone NOT NULL DEFAULT now(),
  fin timestamp without time zone,
  activa boolean NOT NULL DEFAULT true,
  CONSTRAINT sanciones_pkey PRIMARY KEY (id),
  CONSTRAINT sanciones_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id),
  CONSTRAINT sanciones_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.usuarios(id)
);
CREATE TABLE public.menu_casino (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tienda_id uuid NOT NULL,
  fecha date NOT NULL,
  precio integer,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  nombre character varying,
  descripcion text,
  CONSTRAINT menu_casino_pkey PRIMARY KEY (id),
  CONSTRAINT menu_casino_tienda_id_fkey FOREIGN KEY (tienda_id) REFERENCES public.tiendas(id)
);
CREATE TABLE public.menu_casino_platos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  menu_id uuid NOT NULL,
  nombre character varying NOT NULL,
  descripcion text,
  imagen_url character varying,
  orden integer DEFAULT 0,
  creado_en timestamp without time zone DEFAULT now(),
  precio integer,
  etiqueta character varying,
  CONSTRAINT menu_casino_platos_pkey PRIMARY KEY (id),
  CONSTRAINT menu_casino_platos_menu_id_fkey FOREIGN KEY (menu_id) REFERENCES public.menu_casino(id)
);
CREATE TABLE public.resenias_platos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  plato_id uuid NOT NULL,
  calificacion integer NOT NULL CHECK (calificacion >= 1 AND calificacion <= 5),
  comentario text,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT resenias_platos_pkey PRIMARY KEY (id),
  CONSTRAINT resenias_platos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id),
  CONSTRAINT resenias_platos_plato_id_fkey FOREIGN KEY (plato_id) REFERENCES public.menu_casino_platos(id)
);
CREATE TABLE public.resenias_tienda (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  tienda_id uuid NOT NULL,
  calificacion integer NOT NULL CHECK (calificacion >= 1 AND calificacion <= 5),
  comentario text,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT resenias_tienda_pkey PRIMARY KEY (id),
  CONSTRAINT resenias_tienda_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id),
  CONSTRAINT resenias_tienda_tienda_id_fkey FOREIGN KEY (tienda_id) REFERENCES public.tiendas(id)
);
CREATE TABLE public.favoritos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  producto_id uuid NOT NULL,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT favoritos_pkey PRIMARY KEY (id),
  CONSTRAINT favoritos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id),
  CONSTRAINT favoritos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id)
);
CREATE TABLE public.invitaciones_trabajador (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  email text NOT NULL,
  tienda_id uuid NOT NULL,
  token text NOT NULL UNIQUE,
  usado boolean DEFAULT false,
  expira_en timestamp without time zone DEFAULT (now() + '48:00:00'::interval),
  creado_en timestamp without time zone DEFAULT now(),
  CONSTRAINT invitaciones_trabajador_pkey PRIMARY KEY (id),
  CONSTRAINT invitaciones_trabajador_tienda_id_fkey FOREIGN KEY (tienda_id) REFERENCES public.tiendas(id)
);
CREATE TABLE public.resenias_publicacion (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL,
  publicacion_id uuid NOT NULL,
  calificacion integer NOT NULL CHECK (calificacion >= 1 AND calificacion <= 5),
  comentario text,
  creado_en timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT resenias_publicacion_pkey PRIMARY KEY (id),
  CONSTRAINT resenias_publicacion_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id),
  CONSTRAINT resenias_publicacion_publicacion_id_fkey FOREIGN KEY (publicacion_id) REFERENCES public.publicaciones(id)
);
CREATE TABLE public.invitaciones_duenio (
  id integer NOT NULL DEFAULT nextval('invitaciones_duenio_id_seq'::regclass),
  email text NOT NULL,
  tipo_tienda_id integer NOT NULL,
  token text NOT NULL UNIQUE,
  usado boolean NOT NULL DEFAULT false,
  expira_en timestamp with time zone NOT NULL DEFAULT (now() + '48:00:00'::interval),
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT invitaciones_duenio_pkey PRIMARY KEY (id),
  CONSTRAINT invitaciones_duenio_tipo_tienda_id_fkey FOREIGN KEY (tipo_tienda_id) REFERENCES public.tipo_tienda(id)
);
CREATE TABLE public.reset_password_tokens (
  id integer NOT NULL DEFAULT nextval('reset_password_tokens_id_seq'::regclass),
  usuario_id uuid NOT NULL,
  token text NOT NULL UNIQUE,
  usado boolean NOT NULL DEFAULT false,
  expira_en timestamp with time zone NOT NULL DEFAULT (now() + '01:00:00'::interval),
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT reset_password_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT reset_password_tokens_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id)
);