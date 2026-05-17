const express = require('express');
const router  = express.Router();
const { verificarToken } = require('../middleware/Authmiddleware');
const {
  obtenerTienda,
  listarProductosTienda,
  listarPublicacionesTienda,
  listarReseniasTienda,
  crearReseniaTienda,
  miReseniaTienda,
  listarFavoritos,
  agregarFavorito,
  quitarFavorito,
  listarFavoritosIds,
} = require('../controllers/tiendaController');

// Tienda — público
router.get('/tienda/:id',                        obtenerTienda);
router.get('/tienda/:id/productos-disponibles',  listarProductosTienda);
router.get('/tienda/:id/publicaciones-activas',  listarPublicacionesTienda);
router.get('/tienda/:id/resenias',               listarReseniasTienda);

// Reseñas — requiere token
router.get('/tienda/:id/mi-resenia',  verificarToken, miReseniaTienda);
router.post('/tienda/:id/resenias',   verificarToken, crearReseniaTienda);

// Favoritos — requiere token
router.get('/favoritos',                    verificarToken, listarFavoritos);
router.get('/favoritos/ids',                verificarToken, listarFavoritosIds);
router.post('/favoritos/:productoId',       verificarToken, agregarFavorito);
router.delete('/favoritos/:productoId',     verificarToken, quitarFavorito);

module.exports = router;