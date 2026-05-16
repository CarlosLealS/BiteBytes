const express = require('express');
const router  = express.Router();
const { verificarToken, soloRoles } = require('../middleware/Authmiddleware');
const {
  listarPublicaciones,
  obtenerPublicacionesActivas,
  crearPublicacion,
  editarPublicacion,
  eliminarPublicacion,
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

module.exports = router;