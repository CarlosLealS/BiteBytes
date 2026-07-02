const express = require('express');
const router = express.Router();
const { verificarToken, soloRoles } = require('../middleware/Authmiddleware');
const {
  listarTiendas,
  invitarDuenio,
  eliminarTienda,
  listarTrabajadores,
  crearTrabajador,
  eliminarTrabajador,
  enviarReseteoContrasena,
  listarReportes,
  resolverReporte,
} = require('../controllers/adminController');

// Solo administradores o super admins
const soloAdmin = [verificarToken, soloRoles('admin', 'super_admin')];

// Tiendas
router.get('/tiendas',        ...soloAdmin, listarTiendas);
router.post('/tiendas',       ...soloAdmin, invitarDuenio);
router.delete('/tiendas/:id', ...soloAdmin, eliminarTienda);

// Trabajadores
router.get('/trabajadores',        ...soloAdmin, listarTrabajadores);
router.post('/trabajadores',       ...soloAdmin, crearTrabajador);
router.delete('/trabajadores/:id', ...soloAdmin, eliminarTrabajador);

// Reseteo de contraseña (admin envía a cualquier usuario)
router.post('/usuarios/:id/resetear-contrasena', ...soloAdmin, enviarReseteoContrasena);

// Reportes y sanciones
router.get('/reportes',                 ...soloAdmin, listarReportes);
router.post('/reportes/:id/resolver',   ...soloAdmin, resolverReporte);

module.exports = router;
