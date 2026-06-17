const express = require('express');
const router = express.Router();
const { verificarToken, soloRoles } = require('../middleware/Authmiddleware');
const {
  listarTiendas,
  crearTienda,
  eliminarTienda,
  listarTrabajadores,
  crearTrabajador,
  eliminarTrabajador
} = require('../controllers/adminController');

// Solo administradores o super admins
const soloAdmin = [verificarToken, soloRoles('admin', 'super_admin')];

// Tiendas
router.get('/tiendas',       ...soloAdmin, listarTiendas);
router.post('/tiendas',      ...soloAdmin, crearTienda);
router.delete('/tiendas/:id', ...soloAdmin, eliminarTienda);

// Trabajadores
router.get('/trabajadores',       ...soloAdmin, listarTrabajadores);
router.post('/trabajadores',      ...soloAdmin, crearTrabajador);
router.delete('/trabajadores/:id', ...soloAdmin, eliminarTrabajador);

module.exports = router;
