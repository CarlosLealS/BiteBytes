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

// GET /api/publicaciones/activas
// Publicaciones activas, no expiradas, de tiendas NO casino
const listarPublicacionesActivas = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.*,
              t.nombre AS tienda_nombre,
              JSON_AGG(
                JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                ORDER BY pi.orden
              ) FILTER (WHERE pi.id IS NOT NULL) AS imagenes
       FROM publicaciones p
       JOIN tiendas t ON t.id = p.tienda_id
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       LEFT JOIN publicacion_imagenes pi ON pi.publicacion_id = p.id
       WHERE p.activa = true
         AND tt.es_casino = false
         AND p.publicar_en <= NOW()
         AND (p.expira_en IS NULL OR p.expira_en > NOW())
       GROUP BY p.id, t.nombre
       ORDER BY p.publicar_en DESC`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando publicaciones activas:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/publicaciones/casino
// Publicaciones activas, no expiradas, de tiendas tipo casino
const listarPublicacionesCasino = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.*,
              t.nombre AS tienda_nombre,
              JSON_AGG(
                JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                ORDER BY pi.orden
              ) FILTER (WHERE pi.id IS NOT NULL) AS imagenes
       FROM publicaciones p
       JOIN tiendas t ON t.id = p.tienda_id
       JOIN tipo_tienda tt ON t.tipo_tienda_id = tt.id
       LEFT JOIN publicacion_imagenes pi ON pi.publicacion_id = p.id
       WHERE p.activa = true
         AND tt.es_casino = true
         AND p.publicar_en <= NOW()
         AND (p.expira_en IS NULL OR p.expira_en > NOW())
       GROUP BY p.id, t.nombre
       ORDER BY p.publicar_en DESC`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando publicaciones casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/menu-casino/hoy
// Menús de casino del día actual
const listarMenuCasinoHoy = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT mc.*, t.nombre AS tienda_nombre
       FROM menu_casino mc
       JOIN tiendas t ON t.id = mc.tienda_id
       WHERE mc.fecha = CURRENT_DATE
         AND t.activa = true
       ORDER BY t.nombre`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando menú casino:', error.message);
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

module.exports = {
  listarTiendas,
  listarPublicacionesActivas,
  listarPublicacionesCasino,
  listarMenuCasinoHoy,
  buscarProductos,
};
