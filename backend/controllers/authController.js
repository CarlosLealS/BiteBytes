const bcrypt = require('bcrypt');
const jwt    = require('jsonwebtoken');
const pool   = require('../config/db');

const registrar = async (req, res) => {
  const { nombre, email, password, rol_id } = req.body;

  if (!nombre || !email || !password) {
    return res.status(400).json({ error: 'Nombre, email y password son requeridos' });
  }

  try {
    const existe = await pool.query('SELECT id FROM usuarios WHERE email = $1', [email]);
    if (existe.rows.length > 0) {
      return res.status(409).json({ error: 'El email ya está registrado' });
    }

    const password_hash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
       VALUES ($1, $2, $3, $4)
       RETURNING id, nombre, email, rol_id, creado_en`,
      [nombre, email, password_hash, rol_id || 5]
    );

    res.status(201).json({ mensaje: 'Usuario registrado correctamente', usuario: result.rows[0] });
  } catch (error) {
    console.error('Error en registro:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

const login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email y password son requeridos' });
  }

  try {
    const result = await pool.query(
      `SELECT u.id, u.nombre, u.email, u.password_hash, u.activo, r.nombre AS rol
       FROM usuarios u
       JOIN roles r ON r.id = u.rol_id
       WHERE u.email = $1`,
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    const usuario = result.rows[0];

    if (!usuario.activo) {
      return res.status(403).json({ error: 'Tu cuenta está desactivada' });
    }

    const passwordValido = await bcrypt.compare(password, usuario.password_hash);
    if (!passwordValido) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    let tiendaId     = null;
    let nombreTienda = null;
    let esCasino     = false;

    if (usuario.rol === 'duenio_tienda') {
      const tienda = await pool.query(
        `SELECT t.id, t.nombre, tt.es_casino
         FROM tiendas t
         JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
         WHERE t.duenio_id = $1 AND t.activa = true LIMIT 1`,
        [usuario.id]
      );
      if (tienda.rows.length > 0) {
        tiendaId     = tienda.rows[0].id;
        nombreTienda = tienda.rows[0].nombre;
        esCasino     = tienda.rows[0].es_casino;
      }
    }

    if (usuario.rol === 'trabajador_tienda') {
      const tienda = await pool.query(
        `SELECT t.id, t.nombre, tip.es_casino
         FROM trabajadores_tienda tt
         JOIN tiendas t   ON t.id  = tt.tienda_id
         JOIN tipo_tienda tip ON tip.id = t.tipo_tienda_id
         WHERE tt.usuario_id = $1 AND t.activa = true LIMIT 1`,
        [usuario.id]
      );
      if (tienda.rows.length > 0) {
        tiendaId     = tienda.rows[0].id;
        nombreTienda = tienda.rows[0].nombre;
        esCasino     = tienda.rows[0].es_casino;
      }
    }

    const token = jwt.sign(
      {
        id:        usuario.id,
        email:     usuario.email,
        nombre:    usuario.nombre,
        rol:       usuario.rol,
        tienda_id: tiendaId,
        tienda:    nombreTienda,
        es_casino: esCasino,
      },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    res.json({
      mensaje: 'Inicio de sesión exitoso',
      token,
      usuario: {
        id:        usuario.id,
        nombre:    usuario.nombre,
        email:     usuario.email,
        rol:       usuario.rol,
        tienda_id: tiendaId,
        tienda:    nombreTienda,
        es_casino: esCasino,
      }
    });
  } catch (error) {
    console.error('Error en login:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

const logout = async (req, res) => {
  try {
    const usuarioId = req.usuario.id;
    res.json({ mensaje: 'Sesión cerrada correctamente', usuarioId });
  } catch (error) {
    console.error('Error en logout:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/verificar-invitacion-duenio?token=...
const verificarInvitacionDuenio = async (req, res) => {
  const { token } = req.query;
  if (!token) return res.status(400).json({ error: 'Token requerido' });

  try {
    const result = await pool.query(
      `SELECT i.email, tt.nombre AS tipo_tienda, tt.id AS tipo_tienda_id
       FROM invitaciones_duenio i
       JOIN tipo_tienda tt ON tt.id = i.tipo_tienda_id
       WHERE i.token = $1 AND i.usado = false AND i.expira_en > NOW()`,
      [token]
    );
    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'El enlace es inválido o ha expirado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error verificando invitación dueño:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/registro-duenio
const registrarDuenio = async (req, res) => {
  const { token, nombre, password, nombre_tienda, descripcion } = req.body;

  if (!token || !nombre || !password || !nombre_tienda) {
    return res.status(400).json({ error: 'Token, nombre, contraseña y nombre de tienda son requeridos' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const invitacion = await client.query(
      `SELECT * FROM invitaciones_duenio
       WHERE token = $1 AND usado = false AND expira_en > NOW()`,
      [token]
    );
    if (invitacion.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'El enlace es inválido o ha expirado' });
    }

    const { email, tipo_tienda_id } = invitacion.rows[0];

    const existe = await client.query('SELECT id FROM usuarios WHERE email = $1', [email]);
    if (existe.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'El email ya tiene una cuenta registrada' });
    }

    // Crear el usuario con rol duenio_tienda (rol_id = 3)
    const password_hash = await bcrypt.hash(password, 10);
    const usuario = await client.query(
      `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
       VALUES ($1, $2, $3, 3)
       RETURNING id, nombre, email`,
      [nombre, email, password_hash]
    );

    // Crear la tienda
    await client.query(
      `INSERT INTO tiendas (nombre, descripcion, tipo_tienda_id, duenio_id)
       VALUES ($1, $2, $3, $4)`,
      [nombre_tienda, descripcion || null, tipo_tienda_id, usuario.rows[0].id]
    );

    // Marcar invitación como usada
    await client.query(
      'UPDATE invitaciones_duenio SET usado = true WHERE token = $1',
      [token]
    );

    await client.query('COMMIT');

    res.status(201).json({
      mensaje: 'Cuenta y tienda creadas correctamente. Ya puedes iniciar sesión.',
      usuario: usuario.rows[0],
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error registrando dueño:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// GET /api/verificar-reset-contrasena?token=...
const verificarResetContrasena = async (req, res) => {
  const { token } = req.query;
  if (!token) return res.status(400).json({ error: 'Token requerido' });

  try {
    const result = await pool.query(
      `SELECT u.email, u.nombre
       FROM reset_password_tokens rt
       JOIN usuarios u ON u.id = rt.usuario_id
       WHERE rt.token = $1 AND rt.usado = false AND rt.expira_en > NOW()`,
      [token]
    );
    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'El enlace es inválido o ha expirado' });
    }
    res.json({ email: result.rows[0].email, nombre: result.rows[0].nombre });
  } catch (error) {
    console.error('Error verificando token de reseteo:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/resetear-contrasena
const resetearContrasena = async (req, res) => {
  const { token, password } = req.body;

  if (!token || !password) {
    return res.status(400).json({ error: 'Token y nueva contraseña son requeridos' });
  }

  if (password.length < 6) {
    return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const result = await client.query(
      `SELECT rt.usuario_id
       FROM reset_password_tokens rt
       WHERE rt.token = $1 AND rt.usado = false AND rt.expira_en > NOW()`,
      [token]
    );

    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'El enlace es inválido o ha expirado' });
    }

    const { usuario_id } = result.rows[0];
    const password_hash = await bcrypt.hash(password, 10);

    await client.query(
      'UPDATE usuarios SET password_hash = $1 WHERE id = $2',
      [password_hash, usuario_id]
    );

    await client.query(
      'UPDATE reset_password_tokens SET usado = true WHERE token = $1',
      [token]
    );

    await client.query('COMMIT');

    res.json({ mensaje: 'Contraseña actualizada correctamente. Ya puedes iniciar sesión.' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error reseteando contraseña:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

module.exports = {
  registrar,
  login,
  logout,
  verificarInvitacionDuenio,
  registrarDuenio,
  verificarResetContrasena,
  resetearContrasena,
};