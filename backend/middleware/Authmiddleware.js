const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const verificarToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Acceso denegado, token requerido' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.usuario = decoded;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Token inválido o expirado' });
  }
};

const soloRoles = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.usuario.rol)) {
      return res.status(403).json({ error: 'No tienes permisos para esta acción' });
    }
    next();
  };
};

const verificarSancion = async (req, res, next) => {
  try {
    const userId = req.usuario.id;
    const result = await pool.query(
      `SELECT fin, motivo FROM sanciones 
       WHERE usuario_id = $1 AND activa = true AND (fin IS NULL OR fin > NOW())
       ORDER BY fin DESC LIMIT 1`,
      [userId]
    );

    if (result.rows.length > 0) {
      const sancion = result.rows[0];
      let msj = 'No puedes realizar esta acción porque estás sancionado.';
      if (sancion.fin) {
        msj += ` La sanción termina el ${new Date(sancion.fin).toLocaleDateString()}.`;
      }
      return res.status(403).json({ error: msj });
    }
    next();
  } catch (error) {
    console.error('Error verificando sanción:', error.message);
    res.status(500).json({ error: 'Error verificando estado del usuario' });
  }
};

module.exports = { verificarToken, soloRoles, verificarSancion };