const pool = require('../config/db');

// GET /api/tienda/:id (detalle completo de una tienda)
const obtenerTienda = async (req, res) => {
  const { id } = req.params;
  try {
    const tienda = await pool.query(
      `SELECT t.*, tt.nombre AS tipo, tt.es_casino,
              ROUND(AVG(r.calificacion)::numeric, 1) AS valoracion_media,
              COUNT(r.id) AS total_resenias
       FROM tiendas t
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       LEFT JOIN resenias_tienda r ON r.tienda_id = t.id
       WHERE t.id = $1 AND t.activa = true
       GROUP BY t.id, tt.nombre, tt.es_casino`,
      [id]
    );
    if (tienda.rows.length === 0) {
      return res.status(404).json({ error: 'Tienda no encontrada' });
    }
    res.json(tienda.rows[0]);
  } catch (error) {
    console.error('Error obteniendo tienda:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/tienda/:id/productos-disponibles (productos disponibles de la tienda)
const listarProductosTienda = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT p.*, c.nombre AS categoria,
              ROUND(AVG(r.calificacion)::numeric, 1) AS valoracion_media,
              COUNT(r.id) AS total_resenias
       FROM productos p
       LEFT JOIN categorias_producto c ON c.id = p.categoria_id
       LEFT JOIN resenias r ON r.producto_id = p.id
       WHERE p.tienda_id = $1 AND p.disponible = true
       GROUP BY p.id, c.nombre
       ORDER BY p.nombre`,
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando productos tienda:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/tienda/:id/publicaciones-activas (publicaciones activas de la tienda)
const listarPublicacionesTienda = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT p.*,
              COALESCE(
                JSON_AGG(
                  JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                  ORDER BY pi.orden
                ) FILTER (WHERE pi.id IS NOT NULL),
                '[]'::json
              ) AS imagenes
       FROM publicaciones p
       LEFT JOIN publicacion_imagenes pi ON pi.publicacion_id = p.id
       WHERE p.tienda_id = $1
         AND p.activa = true
         AND p.publicar_en <= NOW()
         AND (p.expira_en IS NULL OR p.expira_en > NOW())
       GROUP BY p.id
       ORDER BY p.publicar_en DESC`,
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando publicaciones tienda:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/tienda/:id/resenias
const listarReseniasTienda = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT r.*, u.nombre AS usuario_nombre
       FROM resenias_tienda r
       JOIN usuarios u ON u.id = r.usuario_id
       WHERE r.tienda_id = $1
       ORDER BY r.creado_en DESC
       LIMIT 20`,
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando reseñas tienda:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/tienda/:id/resenias (crear o actualizar reseña)
const crearReseniaTienda = async (req, res) => {
  const { id } = req.params;
  const { calificacion, comentario } = req.body;

  if (!calificacion || calificacion < 1 || calificacion > 5) {
    return res.status(400).json({ error: 'Calificación debe ser entre 1 y 5' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO resenias_tienda (usuario_id, tienda_id, calificacion, comentario)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (usuario_id, tienda_id)
       DO UPDATE SET calificacion = $3, comentario = $4, creado_en = NOW()
       RETURNING *`,
      [req.usuario.id, id, calificacion, comentario || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creando reseña tienda:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/tienda/:id/mi-resenia (reseña del usuario actual)
const miReseniaTienda = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT * FROM resenias_tienda
       WHERE tienda_id = $1 AND usuario_id = $2`,
      [id, req.usuario.id]
    );
    res.json(result.rows[0] || null);
  } catch (error) {
    console.error('Error obteniendo mi reseña:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/favoritos (mis favoritos)
const listarFavoritos = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT f.id AS favorito_id, f.creado_en AS agregado_en,
              p.*, t.nombre AS tienda_nombre, c.nombre AS categoria
       FROM favoritos f
       JOIN productos p ON p.id = f.producto_id
       JOIN tiendas t ON t.id = p.tienda_id
       LEFT JOIN categorias_producto c ON c.id = p.categoria_id
       WHERE f.usuario_id = $1
       ORDER BY f.creado_en DESC`,
      [req.usuario.id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando favoritos:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/favoritos/:productoId (agregar a favoritos)
const agregarFavorito = async (req, res) => {
  const { productoId } = req.params;
  try {
    await pool.query(
      `INSERT INTO favoritos (usuario_id, producto_id)
       VALUES ($1, $2)
       ON CONFLICT (usuario_id, producto_id) DO NOTHING`,
      [req.usuario.id, productoId]
    );
    res.status(201).json({ mensaje: 'Agregado a favoritos' });
  } catch (error) {
    console.error('Error agregando favorito:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// DELETE /api/favoritos/:productoId (quitar de favoritos)
const quitarFavorito = async (req, res) => {
  const { productoId } = req.params;
  try {
    await pool.query(
      `DELETE FROM favoritos WHERE usuario_id = $1 AND producto_id = $2`,
      [req.usuario.id, productoId]
    );
    res.json({ mensaje: 'Eliminado de favoritos' });
  } catch (error) {
    console.error('Error quitando favorito:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/favoritos/ids (IDs de productos favoritos del usuario)
const listarFavoritosIds = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT producto_id FROM favoritos WHERE usuario_id = $1`,
      [req.usuario.id]
    );
    res.json(result.rows.map(r => r.producto_id));
  } catch (error) {
    console.error('Error listando IDs favoritos:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};
const listarTrabajadoresTienda = async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(
      `SELECT u.id, u.nombre, u.email, t.desde
       FROM trabajadores t
       JOIN usuarios u ON u.id = t.usuario_id
       WHERE t.tienda_id = $1
       ORDER BY t.desde DESC`,
      [id]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener trabajadores' });
  }
};

module.exports = {
  obtenerTienda,
  listarProductosTienda,
  listarPublicacionesTienda,
  listarReseniasTienda,
  crearReseniaTienda,
  miReseniaTienda,
  listarFavoritos,
  agregarFavorito,
  quitarFavorito,
  listarFavoritosIds,
  listarTrabajadoresTienda,
};