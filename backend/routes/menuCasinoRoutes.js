const express = require('express');
const router  = express.Router();
const { verificarToken, soloRoles, verificarSancion } = require('../middleware/Authmiddleware');
const {
  listarMenuCasinoHoy,
  listarMenusCasino,
  crearMenuCasino,
  editarMenuCasino,
  eliminarMenuCasino,
  crearResenia,
} = require('../controllers/menuCasinoController');
 
const soloDuenio = [verificarToken, soloRoles('duenio_tienda', 'admin', 'super_admin')];
 
// Público — para alumnos
router.get('/menu-casino/hoy', listarMenuCasinoHoy);
 
// Solo dueño casino
router.get('/menu-casino/tienda/:id', ...soloDuenio, listarMenusCasino);
router.post('/menu-casino',           ...soloDuenio, crearMenuCasino);
router.put('/menu-casino/:id',        ...soloDuenio, editarMenuCasino);
router.delete('/menu-casino/:id',     ...soloDuenio, eliminarMenuCasino);
 
// Valoraciones de platos — cualquier usuario autenticado
router.post('/menu-casino/platos/:id/resenias', verificarToken, verificarSancion, crearResenia);
 
module.exports = router;