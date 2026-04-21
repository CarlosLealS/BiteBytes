const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const pool = require('./db');

const DOMINIOS_PERMITIDOS = ['ucn.cl', 'alumnos.ucn.cl', 'soyucn.edu.co'];

passport.use(new GoogleStrategy({
  clientID:     process.env.GOOGLE_CLIENT_ID,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  callbackURL:  process.env.GOOGLE_CALLBACK_URL,
}, async (accessToken, refreshToken, profile, done) => {
  try {
    const email = profile.emails[0].value;
    const dominio = email.split('@')[1];

    // Verificar dominio permitido
    if (!DOMINIOS_PERMITIDOS.includes(dominio)) {
      return done(null, false, { mensaje: 'Correo no permitido. Debes usar tu correo institucional UCN.' });
    }

    // Buscar si el usuario ya existe
    const resultado = await pool.query(
      `SELECT u.id, u.nombre, u.email, u.activo, r.nombre AS rol
       FROM usuarios u
       JOIN roles r ON r.id = u.rol_id
       WHERE u.email = $1`,
      [email]
    );

    if (resultado.rows.length > 0) {
      const usuario = resultado.rows[0];
      if (!usuario.activo) {
        return done(null, false, { mensaje: 'Tu cuenta está desactivada.' });
      }
      return done(null, usuario);
    }

    // Crear usuario nuevo como alumno (rol_id = 5)
    const nuevo = await pool.query(
      `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
       VALUES ($1, $2, $3, 5)
       RETURNING id, nombre, email, rol_id`,
      [profile.displayName, email, 'google_oauth']
    );

    const usuarioNuevo = { ...nuevo.rows[0], rol: 'alumno' };
    return done(null, usuarioNuevo);

  } catch (error) {
    return done(error, null);
  }
}));

module.exports = passport;