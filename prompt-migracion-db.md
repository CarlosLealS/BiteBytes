# Prompt para migrar BiteBytes de Supabase a PostgreSQL local en la VM

Copia y pega esto en tu asistente de IA (Claude Code u otro agente con acceso a la terminal de la VM):

---

Estoy migrando la base de datos de mi proyecto BiteBytes desde Supabase (Postgres cloud) hacia un contenedor de PostgreSQL corriendo localmente en esta VM con Podman. Ya tengo:

- Un dump generado en `~/BiteBytes/bitebytes_dump.sql` (formato custom de pg_dump, extraído desde Supabase con `pg_dump -F c`).
- Un `podman-compose.yml` en `~/BiteBytes` que actualmente define los servicios `frontend` y `backend`.
- El backend lee la conexión a la base de datos desde la variable `DATABASE_URL` en `~/BiteBytes/backend/.env`, actualmente apuntando a Supabase.
- El backend usa un cliente Postgres estándar (no el SDK de Supabase), así que solo es cuestión de cambiar el connection string.

Necesito que hagas lo siguiente, en este orden, verificando el resultado de cada paso antes de seguir al siguiente:

## 1. Actualizar `podman-compose.yml`
Agrega un nuevo servicio `postgres` al archivo `~/BiteBytes/podman-compose.yml`, sin romper los servicios `frontend` y `backend` existentes:

```yaml
  postgres:
    image: docker.io/library/postgres:16-alpine
    container_name: bitebytes-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=REEMPLAZAR_CON_CLAVE_SEGURA
      - POSTGRES_DB=bitebytes
    ports:
      - "0.0.0.0:5432:5432"
    volumes:
      - bitebytes_pgdata:/var/lib/postgresql/data
```

Y agrega al final del archivo (o al bloque `volumes` si ya existe uno):
```yaml
volumes:
  bitebytes_pgdata:
```

También agrega `depends_on: [postgres]` al servicio `backend`.

Usa la contraseña que te indique (variable `REEMPLAZAR_CON_CLAVE_SEGURA` arriba) — pídeme que te la confirme si no la tienes, no la inventes tú.

## 2. Levantar solo el contenedor de Postgres
```bash
cd ~/BiteBytes
/usr/local/bin/podman-compose up -d postgres
sleep 5
podman ps
```
Confirma que `bitebytes-postgres` aparece con estado `Up` y el puerto `5432` mapeado antes de continuar.

## 3. Restaurar el dump dentro del contenedor
```bash
podman cp bitebytes_dump.sql bitebytes-postgres:/tmp/dump.sql
podman exec -it bitebytes-postgres pg_restore -U postgres -d bitebytes --no-owner --no-privileges /tmp/dump.sql
```
Es normal ver errores de "role ... does not exist" para roles propios de Supabase (`authenticator`, `anon`, `authenticated`, `service_role`, etc.) — ignóralos, no son necesarios en el Postgres local. Si ves errores distintos a esos (por ejemplo de tablas o datos), repórtalos antes de seguir.

## 4. Verificar que los datos llegaron bien
```bash
podman exec -it bitebytes-postgres psql -U postgres -d bitebytes -c "\dt"
```
Debe listar las tablas del proyecto. Opcionalmente, cuenta filas de alguna tabla clave para comparar con Supabase.

## 5. Actualizar `backend/.env`
Cambia la línea `DATABASE_URL` en `~/BiteBytes/backend/.env` de apuntar a Supabase a apuntar al contenedor local:
```
DATABASE_URL=postgresql://postgres:REEMPLAZAR_CON_CLAVE_SEGURA@bitebytes-postgres:5432/bitebytes
```
(usa la misma contraseña del paso 1). No toques ninguna otra variable del `.env` (Google OAuth, JWT, Cloudinary, Gmail deben quedar igual).

## 6. Redeploy completo
```bash
cd ~/BiteBytes
/usr/local/bin/podman-compose up -d --build
podman ps
```

## 7. Verificación final
```bash
curl -v http://localhost:3000
curl -v http://localhost:8080
```
El backend debe responder `200 OK` con el JSON de la API, y el frontend debe servir el HTML de Flutter. Además, prueba desde el navegador algún endpoint que consulte datos reales (ej. login o listado de productos) para confirmar que el backend está leyendo correctamente desde el Postgres local y no desde Supabase.

Si algo falla en cualquier paso, muéstrame el error completo antes de intentar solucionarlo por tu cuenta.

---

**Nota:** no incluí las credenciales reales de Supabase ni la contraseña del Postgres nuevo en este prompt — pégaselas directamente a tu agente de IA cuando te las pida, o dile "usa la clave que ya definimos" si tu agente tiene memoria de la conversación anterior.
