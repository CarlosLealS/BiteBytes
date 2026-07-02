const express = require('express');
const router = express.Router();
const { verificarToken } = require('../middleware/Authmiddleware');
const {
  listarMisNotificaciones,
  marcarLeida
} = require('../controllers/notificacionesController');

router.get('/notificaciones', verificarToken, listarMisNotificaciones);
router.patch('/notificaciones/:id/leida', verificarToken, marcarLeida);

module.exports = router;
