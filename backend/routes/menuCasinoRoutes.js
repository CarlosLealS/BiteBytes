const express = require('express');
const router  = express.Router();
const { verificarToken: auth } = require('../middleware/Authmiddleware');
const upload  = require('../middleware/upload');
const {
  listarMenuCasinoHoy,
  listarMenusCasino,
  crearMenuCasino,
  editarMenuCasino,
  eliminarMenuCasino,
  agregarPlato,
  editarPlato,
  eliminarPlato,
} = require('../controllers/menuCasinoController');

// ── Menú casino ────────────────────────────────────────────
router.get('/hoy',                auth, listarMenuCasinoHoy);
router.get('/tienda/:id',         auth, listarMenusCasino);
router.post('/',                  auth, crearMenuCasino);
router.put('/:id',                auth, editarMenuCasino);
router.delete('/:id',             auth, eliminarMenuCasino);

// ── Platos (sub-recurso) ───────────────────────────────────
// La imagen es opcional → upload.single('imagen') la maneja si viene
router.post('/:menuId/platos',          auth, upload.single('imagen'), agregarPlato);
router.put('/platos/:platoId',          auth, upload.single('imagen'), editarPlato);
router.delete('/platos/:platoId',       auth, eliminarPlato);

module.exports = router;