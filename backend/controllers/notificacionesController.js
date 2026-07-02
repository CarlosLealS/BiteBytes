const pool = require('../config/db');

// GET /api/notificaciones
const listarMisNotificaciones = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT * FROM notificaciones
       WHERE usuario_id = $1
       ORDER BY creado_en DESC
       LIMIT 50`,
      [req.usuario.id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando notificaciones:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// PATCH /api/notificaciones/:id/leida
const marcarLeida = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `UPDATE notificaciones
       SET leida = true
       WHERE id = $1 AND usuario_id = $2
       RETURNING *`,
      [id, req.usuario.id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Notificación no encontrada' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error marcando notificación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarMisNotificaciones,
  marcarLeida
};
