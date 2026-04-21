const express  = require('express');
const router   = express.Router();
const passport = require('passport');
const jwt      = require('jsonwebtoken');
const { registrar, login } = require('../controllers/authController');

router.post('/registro', registrar);
router.post('/login', login);

router.get('/google', passport.authenticate('google', {
  scope: ['profile', 'email'],
  session: false,
}));

router.get('/google/callback',
  passport.authenticate('google', { session: false, failureRedirect: '/api/auth/google/fallo' }),
  (req, res) => {
    const token = jwt.sign(
      { id: req.user.id, email: req.user.email, rol: req.user.rol },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );
    res.redirect(`http://localhost:4000?token=${token}`);
  }
);

router.get('/google/fallo', (req, res) => {
  res.status(401).json({ error: 'Correo no permitido. Debes usar tu correo institucional UCN.' });
});

module.exports = router;