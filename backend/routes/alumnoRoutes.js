const express = require('express');
const router  = express.Router();
const { verificarToken } = require('../middleware/Authmiddleware');
const {
  listarTiendas,
  listarPublicacionesActivas,
  listarPublicacionesCasino,
  listarMenuCasinoHoy,
  buscarProductos,
} = require('../controllers/alumnoController');

// Tiendas — acceso público (visitantes también pueden ver el mapa)
router.get('/tiendas', listarTiendas);

// Publicaciones activas — acceso público (NO casino)
router.get('/publicaciones/activas', listarPublicacionesActivas);

// Publicaciones del casino — acceso público
router.get('/publicaciones/casino', listarPublicacionesCasino);

// Menú casino hoy — acceso público
router.get('/menu-casino/hoy', listarMenuCasinoHoy);

// Búsqueda de productos — requiere token
router.get('/productos/buscar', verificarToken, buscarProductos);

module.exports = router;
