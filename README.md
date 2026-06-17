# BiteBytes

BiteBytes es una plataforma integral desarrollada para facilitar la gestión de tiendas de comida y casinos en el campus de la UCN, permitiendo a los estudiantes revisar menús, ofertas y ubicaciones de las distintas opciones gastronómicas disponibles.

## Tecnologías Utilizadas

- **Frontend**: Flutter (Web, Android, iOS)
- **Backend**: Node.js, Express
- **Base de Datos**: PostgreSQL
- **Autenticación**: JWT (JSON Web Tokens), bcrypt
- **Infraestructura**: Podman / Docker (configurado vía podman-compose)

## Arquitectura y Roles

El sistema cuenta con un control de acceso basado en roles (RBAC) para distintas experiencias de usuario:

- **super_admin / admin (UCN)**: Tienen acceso al Panel Administrativo UCN para la gestión global de tiendas y trabajadores en el campus.
- **duenio_tienda**: Propietario de un establecimiento. Puede gestionar su propia tienda, menú, publicaciones, ofertas y a sus trabajadores.
- **trabajador_tienda**: Personal de la tienda que puede gestionar productos y ventas de la tienda a la que está asociado.
- **alumno**: Usuarios generales que pueden buscar comida, revisar menús diarios, ver publicaciones de ofertas, evaluar y marcar favoritos.

## Instalación y Ejecución Local

Para ejecutar el proyecto en tu máquina local, necesitarás tener instalado Flutter, Node.js y PostgreSQL.

### Backend

1. Abre una terminal y navega a la carpeta `backend`:
   ```bash
   cd backend
   ```
2. Instala las dependencias:
   ```bash
   npm install
   ```
3. Configura las variables de entorno en el archivo `.env` basándote en el archivo de configuración.
4. Ejecuta el servidor en modo desarrollo:
   ```bash
   npm run dev
   ```

### Frontend

1. Abre otra terminal y navega a la carpeta `bitebytes_app`:
   ```bash
   cd bitebytes_app
   ```
2. Instala las dependencias de Flutter:
   ```bash
   flutter pub get
   ```
3. Ejecuta la aplicación en la web:
   ```bash
   flutter run -d edge --web-port 8080
   ```
*(Nota: Asegúrate de que las variables de entorno como `API_URL` apunten a tu servidor local en `lib/config/env.dart`).*

## Estructura del Repositorio

- `/backend/`: Contiene el código fuente del servidor (Node.js/Express), controladores, middlewares y scripts de base de datos.
- `/bitebytes_app/`: Contiene el código fuente de la aplicación multiplataforma (Flutter).
- `/mockups/`: Contiene diseños o diagramas relacionados con el proyecto.
- `Idea-Proyecto-BiteBytes.pdf`: Documentación de la idea inicial del proyecto.
