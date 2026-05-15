const express  = require('express');
const router   = express.Router();
const passport = require('passport');
const jwt      = require('jsonwebtoken');
const pool     = require('../config/db');
const { registrar, login } = require('../controllers/authController');

const FRONTEND_URL = process.env.FRONTEND_URL || 'http://localhost:4000';

router.post('/registro', registrar);
router.post('/login', login);

router.get('/google', passport.authenticate('google', {
  scope: ['profile', 'email'],
  session: false,
  prompt: 'select_account',
}));

router.get('/google/callback',
  passport.authenticate('google', { session: false, failureRedirect: '/api/auth/google/fallo' }),
  async (req, res) => {
    try {
      // Buscar tienda del usuario si es dueño
      let tiendaId     = null;
      let esCasino     = false;

      if (req.user.rol === 'duenio_tienda') {
        const tienda = await pool.query(
          `SELECT t.id, tt.es_casino
           FROM tiendas t
           JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
           WHERE t.duenio_id = $1 AND t.activa = true LIMIT 1`,
          [req.user.id]
        );
        if (tienda.rows.length > 0) {
          tiendaId = tienda.rows[0].id;
          esCasino = tienda.rows[0].es_casino;
        }
      }

      const token = jwt.sign(
        {
          id:        req.user.id,
          email:     req.user.email,
          rol:       req.user.rol,
          tienda_id: tiendaId,
          es_casino: esCasino,
        },
        process.env.JWT_SECRET,
        { expiresIn: '8h' }
      );

      res.redirect(`${FRONTEND_URL}?token=${token}`);
    } catch (error) {
      console.error('Error en callback Google:', error.message);
      res.redirect('/api/auth/google/fallo');
    }
  }
);

router.get('/google/fallo', (req, res) => {
  res.status(401).send(`
    <html>
      <head>
        <meta charset="utf-8" />
        <title>Acceso no permitido</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            background: #f4f6fb;
            color: #0b1a49;
          }
          .card {
            max-width: 520px;
            padding: 32px;
            margin: 24px;
            border-radius: 16px;
            background: white;
            box-shadow: 0 12px 30px rgba(0, 0, 0, 0.12);
            text-align: center;
          }
          a {
            display: inline-block;
            margin-top: 20px;
            padding: 12px 18px;
            border-radius: 10px;
            background: #001455;
            color: white;
            text-decoration: none;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>Correo no permitido</h1>
          <p>Debes usar tu correo institucional UCN.</p>
          <a href="/api/auth/google">Probar con otra cuenta</a>
        </div>
      </body>
    </html>
  `);
});

module.exports = router;