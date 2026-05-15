const bcrypt = require('bcrypt');
const jwt    = require('jsonwebtoken');
const pool   = require('../config/db');

// Registro de usuario
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

// Inicio de sesión
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

    // Si es dueño de tienda, buscar su tienda y si es casino
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

    // Generar token JWT con es_casino incluido
    const token = jwt.sign(
      {
        id:        usuario.id,
        email:     usuario.email,
        rol:       usuario.rol,
        tienda_id: tiendaId,
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

module.exports = { registrar, login };