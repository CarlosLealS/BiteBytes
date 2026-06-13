const express = require('express');
const router  = express.Router();
const { verificarToken, soloRoles } = require('../middleware/Authmiddleware');
const {
  listarTrabajadores,
  crearTrabajador,
  eliminarTrabajador,
} = require('../controllers/trabajadoresController');

const soloDuenio = [verificarToken, soloRoles('duenio_tienda', 'admin', 'super_admin')];

router.get('/tienda/:id/trabajadores',                        ...soloDuenio, listarTrabajadores);
router.post('/tienda/:id/trabajadores',                       ...soloDuenio, crearTrabajador);
router.delete('/tienda/:tiendaId/trabajadores/:trabajadorId', ...soloDuenio, eliminarTrabajador);

module.exports = router;