const pool   = require('../config/db');
const bcrypt = require('bcrypt');

// GET /api/tienda/:id/trabajadores
const listarTrabajadoresTienda = async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(
      `SELECT u.id, u.nombre, u.email, u.activo, tt.desde, tt.id AS trabajador_id
       FROM trabajadores_tienda tt
       JOIN usuarios u ON u.id = tt.usuario_id
       WHERE tt.tienda_id = $1
       ORDER BY tt.desde DESC`,
      [id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener trabajadores' });
  }
};

// POST /api/tienda/:id/trabajadores — crear cuenta y asignar a la tienda
const crearTrabajador = async (req, res) => {
  const { id } = req.params;
  const { nombre, email, password } = req.body;

  if (!nombre || !email || !password) {
    return res.status(400).json({ error: 'Nombre, email y password son requeridos' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Verificar que la tienda pertenece al dueño
    const tienda = await client.query(
      'SELECT id FROM tiendas WHERE id = $1 AND duenio_id = $2',
      [id, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    // Verificar que el email no existe
    const existe = await client.query(
      'SELECT id FROM usuarios WHERE email = $1',
      [email]
    );
    if (existe.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'El email ya está registrado' });
    }

    // Crear usuario con rol trabajador_tienda (rol_id = 4)
    const password_hash = await bcrypt.hash(password, 10);
    const usuario = await client.query(
      `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
       VALUES ($1, $2, $3, 4)
       RETURNING id, nombre, email, activo, creado_en`,
      [nombre, email, password_hash]
    );

    const nuevoUsuario = usuario.rows[0];

    // Asignar a la tienda
    const trabajador = await client.query(
      `INSERT INTO trabajadores_tienda (usuario_id, tienda_id)
       VALUES ($1, $2)
       RETURNING id AS trabajador_id, desde`,
      [nuevoUsuario.id, id]
    );

    await client.query('COMMIT');

    res.status(201).json({
      ...trabajador.rows[0],
      ...nuevoUsuario,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creando trabajador:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// DELETE /api/tienda/:tiendaId/trabajadores/:trabajadorId
const eliminarTrabajador = async (req, res) => {
  const { tiendaId, trabajadorId } = req.params;

  try {
    // Verificar que la tienda pertenece al dueño
    const tienda = await pool.query(
      'SELECT id FROM tiendas WHERE id = $1 AND duenio_id = $2',
      [tiendaId, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    // Eliminar de trabajadores_tienda
    const result = await pool.query(
      'DELETE FROM trabajadores_tienda WHERE id = $1 AND tienda_id = $2 RETURNING id',
      [trabajadorId, tiendaId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Trabajador no encontrado' });
    }

    res.json({ mensaje: 'Trabajador eliminado de la tienda correctamente' });
  } catch (error) {
    console.error('Error eliminando trabajador:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarTrabajadoresTienda,
  crearTrabajador,
  eliminarTrabajador,
};