const express = require('express');
const router  = express.Router();
const { verificarToken } = require('../middleware/Authmiddleware');
const {
  listarTiendas,
  listarMenuCasinoHoy,
  buscarProductos,
} = require('../controllers/alumnoController');

// Tiendas — acceso público (visitantes también pueden ver el mapa)
router.get('/tiendas', listarTiendas);

// Menú casino hoy — acceso público
router.get('/menu-casino/hoy', listarMenuCasinoHoy);

// Búsqueda de productos — requiere token
router.get('/productos/buscar', verificarToken, buscarProductos);

module.exports = router;
