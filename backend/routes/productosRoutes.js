const express = require('express');
const router  = express.Router();
const { verificarToken, soloRoles } = require('../middleware/Authmiddleware');
const {
  listarProductosTienda,
  listarCategorias,
  crearProducto,
  editarProducto,
  toggleDisponible,
  eliminarProducto,
} = require('../controllers/productosController');

const soloDuenio = [verificarToken, soloRoles('duenio_tienda', 'trabajador_tienda', 'admin', 'super_admin')];

// Categorías (cualquier usuario autenticado puede verlas)
router.get('/categorias', verificarToken, listarCategorias);

// Productos de una tienda
router.get('/tienda/:id/productos', verificarToken, listarProductosTienda);

// CRUD productos (solo dueño)
router.post('/productos',          ...soloDuenio, crearProducto);
router.put('/productos/:id',       ...soloDuenio, editarProducto);
router.patch('/productos/:id',     ...soloDuenio, toggleDisponible);
router.delete('/productos/:id',    ...soloDuenio, eliminarProducto);

module.exports = router;