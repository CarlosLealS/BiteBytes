const express = require('express');
const router  = express.Router();
const { verificarToken, soloRoles } = require('../middleware/Authmiddleware');
const {
  listarPublicaciones,
  obtenerPublicacionesActivas,
  crearPublicacion,
  editarPublicacion,
  eliminarPublicacion,
  listarReseniasPublicacion,
  crearReseniaPublicacion,
  miReseniaPublicacion,
} = require('../controllers/publicacionesController');

const soloDuenio = [verificarToken, soloRoles('duenio_tienda', 'admin', 'super_admin')];

// Publicaciones activas para alumnos — pública, sin token requerido
// IMPORTANTE: debe ir ANTES de cualquier ruta con /:id para evitar conflictos
router.get('/publicaciones/activas', obtenerPublicacionesActivas);

// Listar publicaciones de una tienda (dueño)
router.get('/tienda/:id/publicaciones', verificarToken, listarPublicaciones);

// CRUD publicaciones (solo dueño)
router.post('/publicaciones',       ...soloDuenio, crearPublicacion);
router.put('/publicaciones/:id',    ...soloDuenio, editarPublicacion);
router.delete('/publicaciones/:id', ...soloDuenio, eliminarPublicacion);

// Reseñas de publicaciones — requiere token
router.get('/publicacion/:id/resenias',   verificarToken, listarReseniasPublicacion);
router.get('/publicacion/:id/mi-resenia', verificarToken, miReseniaPublicacion);
router.post('/publicacion/:id/resenias',  verificarToken, crearReseniaPublicacion);

module.exports = router;