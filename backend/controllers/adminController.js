const pool = require('../config/db');
const bcrypt = require('bcrypt');

// GET /api/admin/tiendas
const listarTiendas = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT t.id, t.nombre, t.descripcion, t.activa, tt.nombre AS tipo, tt.es_casino, 
              u.id AS duenio_id, u.nombre AS duenio_nombre, u.email AS duenio_email
       FROM tiendas t
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       JOIN usuarios u ON u.id = t.duenio_id
       ORDER BY t.creado_en DESC`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando tiendas admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/admin/tiendas
const crearTienda = async (req, res) => {
  const { nombre_tienda, descripcion, tipo_tienda_id, duenio_nombre, duenio_email, duenio_password } = req.body;

  if (!nombre_tienda || !tipo_tienda_id || !duenio_nombre || !duenio_email || !duenio_password) {
    return res.status(400).json({ error: 'Faltan datos obligatorios para crear la tienda y/o el dueño' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Manejo del dueño (verificar si existe o crear)
    let duenioId;
    const existeUser = await client.query('SELECT id, rol_id FROM usuarios WHERE email = $1', [duenio_email]);
    
    if (existeUser.rows.length > 0) {
      duenioId = existeUser.rows[0].id;
      // Si el usuario existe pero no es duenio_tienda ni admin, podríamos actualizar su rol
      if (existeUser.rows[0].rol_id !== 3 && existeUser.rows[0].rol_id !== 1 && existeUser.rows[0].rol_id !== 2) {
         await client.query('UPDATE usuarios SET rol_id = 3 WHERE id = $1', [duenioId]);
      }
    } else {
      const password_hash = await bcrypt.hash(duenio_password, 10);
      const nuevoUser = await client.query(
        `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
         VALUES ($1, $2, $3, 3)
         RETURNING id`,
        [duenio_nombre, duenio_email, password_hash]
      );
      duenioId = nuevoUser.rows[0].id;
    }

    // 2. Crear la tienda
    const nuevaTienda = await client.query(
      `INSERT INTO tiendas (nombre, descripcion, tipo_tienda_id, duenio_id)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [nombre_tienda, descripcion || null, tipo_tienda_id, duenioId]
    );

    await client.query('COMMIT');
    res.status(201).json({ mensaje: 'Tienda creada exitosamente', tienda: nuevaTienda.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creando tienda admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// DELETE /api/admin/tiendas/:id
const eliminarTienda = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('DELETE FROM tiendas WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tienda no encontrada' });
    }
    res.json({ mensaje: 'Tienda eliminada correctamente' });
  } catch (error) {
    console.error('Error eliminando tienda admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/admin/trabajadores
const listarTrabajadores = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT tt.id AS trabajador_id, tt.desde, u.id AS usuario_id, u.nombre, u.email, u.activo, 
              t.id AS tienda_id, t.nombre AS tienda_nombre
       FROM trabajadores_tienda tt
       JOIN usuarios u ON u.id = tt.usuario_id
       JOIN tiendas t ON t.id = tt.tienda_id
       ORDER BY t.nombre, u.nombre`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando trabajadores admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/admin/trabajadores
const crearTrabajador = async (req, res) => {
  const { tienda_id, nombre, email, password } = req.body;

  if (!tienda_id || !nombre || !email || !password) {
    return res.status(400).json({ error: 'Faltan datos obligatorios' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Verificar si el usuario ya existe
    const existe = await client.query('SELECT id FROM usuarios WHERE email = $1', [email]);
    if (existe.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'El email ya está registrado' });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const usuario = await client.query(
      `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
       VALUES ($1, $2, $3, 4)
       RETURNING id, nombre, email`,
      [nombre, email, password_hash]
    );

    const trabajador = await client.query(
      `INSERT INTO trabajadores_tienda (usuario_id, tienda_id)
       VALUES ($1, $2)
       RETURNING id AS trabajador_id, desde`,
      [usuario.rows[0].id, tienda_id]
    );

    await client.query('COMMIT');
    res.status(201).json({ mensaje: 'Trabajador creado exitosamente', trabajador: { ...usuario.rows[0], ...trabajador.rows[0] } });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creando trabajador admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// DELETE /api/admin/trabajadores/:id
const eliminarTrabajador = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('DELETE FROM trabajadores_tienda WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Trabajador no encontrado' });
    }
    res.json({ mensaje: 'Trabajador eliminado correctamente' });
  } catch (error) {
    console.error('Error eliminando trabajador admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarTiendas,
  crearTienda,
  eliminarTienda,
  listarTrabajadores,
  crearTrabajador,
  eliminarTrabajador
};
