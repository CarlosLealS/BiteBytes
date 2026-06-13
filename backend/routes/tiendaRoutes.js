const express = require('express');
const router  = express.Router();
const pool    = require('../config/db');
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
  listarTrabajadoresTienda,
  crearTrabajador,
  eliminarTrabajador,
  invitarTrabajador,
  registrarTrabajador,
} = require('../controllers/tiendaController');

// Tienda — público
router.get('/tienda/:id',                       obtenerTienda);
router.get('/tienda/:id/productos-disponibles', listarProductosTienda);
router.get('/tienda/:id/publicaciones-activas', listarPublicacionesTienda);
router.get('/tienda/:id/resenias',              listarReseniasTienda);

// Verificar invitación — público
router.get('/verificar-invitacion', async (req, res) => {
  const { token } = req.query;
  if (!token) return res.status(400).json({ error: 'Token requerido' });
  try {
    const result = await pool.query(
      `SELECT i.email, t.nombre AS tienda
       FROM invitaciones_trabajador i
       JOIN tiendas t ON t.id = i.tienda_id
       WHERE i.token = $1 AND i.usado = false AND i.expira_en > NOW()`,
      [token]
    );
    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'El enlace es inválido o ha expirado' });
    }
    res.json({ email: result.rows[0].email, tienda: result.rows[0].tienda });
  } catch (error) {
    console.error('Error verificando invitación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Registro por invitación — público
router.post('/registro-trabajador', registrarTrabajador);

// Trabajadores — requiere token
router.get('/tienda/:id/trabajadores',                        verificarToken, listarTrabajadoresTienda);
router.post('/tienda/:id/trabajadores',                       verificarToken, crearTrabajador);
router.delete('/tienda/:tiendaId/trabajadores/:trabajadorId', verificarToken, eliminarTrabajador);
router.post('/tienda/:id/invitar-trabajador',                 verificarToken, invitarTrabajador);

// Reseñas — requiere token
router.get('/tienda/:id/mi-resenia',  verificarToken, miReseniaTienda);
router.post('/tienda/:id/resenias',   verificarToken, crearReseniaTienda);

// Favoritos — requiere token
router.get('/favoritos',                  verificarToken, listarFavoritos);
router.get('/favoritos/ids',              verificarToken, listarFavoritosIds);
router.post('/favoritos/:productoId',     verificarToken, agregarFavorito);
router.delete('/favoritos/:productoId',   verificarToken, quitarFavorito);

module.exports = router;