const pool = require('../config/db');

// GET /api/tiendas
const listarTiendas = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT t.id, t.nombre, t.descripcion, t.horario, t.latitud, t.longitud,
              t.imagen_url, tt.nombre AS tipo, tt.es_casino
       FROM tiendas t
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       WHERE t.activa = true
       ORDER BY t.nombre`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando tiendas:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/menu-casino/hoy
// Menús de casino del día actual
const listarMenuCasinoHoy = async (req, res) => {
  try {
    const menus = await pool.query(
      `SELECT mc.*, t.nombre AS tienda_nombre
       FROM menu_casino mc
       JOIN tiendas t ON t.id = mc.tienda_id
       WHERE mc.fecha = CURRENT_DATE AND t.activa = true
       ORDER BY t.nombre`
    );

    const result = await Promise.all(menus.rows.map(async (menu) => {
      const platos = await pool.query(
        `SELECT p.*,
                ROUND(AVG(r.calificacion)::numeric, 1) AS valoracion_media,
                COUNT(r.id) AS total_resenias
         FROM menu_casino_platos p
         LEFT JOIN resenias_platos r ON r.plato_id = p.id
         WHERE p.menu_id = $1
         GROUP BY p.id
         ORDER BY p.orden, p.creado_en`,
        [menu.id]
      );
      return { ...menu, platos: platos.rows };
    }));

    res.json(result);
  } catch (error) {
    console.error('Error listando menú casino hoy:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/productos/buscar?q=...
// Búsqueda de productos por nombre en todas las tiendas
const buscarProductos = async (req, res) => {
  const { q } = req.query;

  if (!q || q.trim().length < 2) {
    return res.status(400).json({ error: 'La búsqueda debe tener al menos 2 caracteres' });
  }

  try {
    const result = await pool.query(
      `SELECT p.id, p.nombre, p.descripcion, p.precio, p.imagen_url, p.disponible,
              t.nombre AS tienda_nombre, t.id AS tienda_id,
              c.nombre AS categoria,
              ROUND(AVG(r.calificacion)::numeric, 1) AS valoracion_media
       FROM productos p
       JOIN tiendas t ON t.id = p.tienda_id
       LEFT JOIN categorias_producto c ON c.id = p.categoria_id
       LEFT JOIN resenias r ON r.producto_id = p.id
       WHERE p.disponible = true
         AND t.activa = true
         AND LOWER(p.nombre) LIKE LOWER($1)
       GROUP BY p.id, t.nombre, t.id, c.nombre
       ORDER BY p.nombre
       LIMIT 50`,
      [`%${q.trim()}%`]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error buscando productos:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/mi-sancion
// Devuelve la sanción activa del usuario autenticado, si existe
const obtenerMiSancion = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT motivo, inicio, fin
       FROM sanciones
       WHERE usuario_id = $1 AND activa = true AND (fin IS NULL OR fin > NOW())
       ORDER BY fin DESC LIMIT 1`,
      [req.usuario.id]
    );
    if (result.rows.length === 0) {
      return res.json({ sancionado: false });
    }
    const s = result.rows[0];
    res.json({
      sancionado: true,
      motivo:     s.motivo,
      inicio:     s.inicio,
      fin:        s.fin,
    });
  } catch (error) {
    console.error('Error obteniendo sanción:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarTiendas,
  listarMenuCasinoHoy,
  buscarProductos,
  obtenerMiSancion,
};
