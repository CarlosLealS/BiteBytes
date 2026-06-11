const pool       = require('../config/db');
const cloudinary = require('../config/cloudinary');

// GET /api/tienda/:id/productos
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
       WHERE p.tienda_id = $1
       GROUP BY p.id, c.nombre
       ORDER BY p.creado_en DESC`,
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando productos:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/categorias
const listarCategorias = async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM categorias_producto ORDER BY nombre');
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando categorías:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/productos
const crearProducto = async (req, res) => {
  const { tienda_id, nombre, descripcion, precio, imagen_url, imagen_public_id, categoria_id, disponible } = req.body;

  if (!nombre || !precio || !tienda_id) {
    return res.status(400).json({ error: 'Nombre, precio y tienda_id son requeridos' });
  }

  try {
    const tienda = await pool.query(
      'SELECT id FROM tiendas WHERE id = $1 AND duenio_id = $2',
      [tienda_id, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    const result = await pool.query(
      `INSERT INTO productos (tienda_id, nombre, descripcion, precio, imagen_url, imagen_public_id, categoria_id, disponible)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [tienda_id, nombre, descripcion || null, precio, imagen_url || null, imagen_public_id || null, categoria_id || null, disponible ?? true]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creando producto:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// PUT /api/productos/:id
const editarProducto = async (req, res) => {
  const { id } = req.params;
  const { nombre, descripcion, precio, imagen_url, imagen_public_id, categoria_id, disponible } = req.body;

  if (!nombre || !precio) {
    return res.status(400).json({ error: 'Nombre y precio son requeridos' });
  }

  try {
    const check = await pool.query(
      `SELECT p.id, p.imagen_public_id FROM productos p
       JOIN tiendas t ON t.id = p.tienda_id
       WHERE p.id = $1 AND t.duenio_id = $2`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para editar este producto' });
    }

    // Si cambia la imagen, eliminar la anterior de Cloudinary
    const publicIdAnterior = check.rows[0].imagen_public_id;
    if (publicIdAnterior && imagen_public_id && publicIdAnterior !== imagen_public_id) {
      await cloudinary.uploader.destroy(publicIdAnterior).catch(console.error);
    }

    const result = await pool.query(
      `UPDATE productos
       SET nombre = $1, descripcion = $2, precio = $3, imagen_url = $4, imagen_public_id = $5,
           categoria_id = $6, disponible = $7, actualizado_en = NOW()
       WHERE id = $8
       RETURNING *`,
      [nombre, descripcion || null, precio, imagen_url || null, imagen_public_id || null, categoria_id || null, disponible ?? true, id]
    );
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error editando producto:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// PATCH /api/productos/:id
const toggleDisponible = async (req, res) => {
  const { id } = req.params;
  const { disponible } = req.body;

  if (disponible === undefined) {
    return res.status(400).json({ error: 'Campo disponible requerido' });
  }

  try {
    const check = await pool.query(
      `SELECT p.id FROM productos p
       JOIN tiendas t ON t.id = p.tienda_id
       WHERE p.id = $1 AND t.duenio_id = $2`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para este producto' });
    }

    const result = await pool.query(
      `UPDATE productos SET disponible = $1, actualizado_en = NOW()
       WHERE id = $2 RETURNING id, nombre, disponible`,
      [disponible, id]
    );
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error actualizando disponibilidad:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// DELETE /api/productos/:id
const eliminarProducto = async (req, res) => {
  const { id } = req.params;
  try {
    const check = await pool.query(
      `SELECT p.id, p.imagen_public_id FROM productos p
       JOIN tiendas t ON t.id = p.tienda_id
       WHERE p.id = $1 AND t.duenio_id = $2`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para eliminar este producto' });
    }

    // Eliminar imagen de Cloudinary si existe
    const publicId = check.rows[0].imagen_public_id;
    if (publicId) {
      await cloudinary.uploader.destroy(publicId).catch(console.error);
    }

    await pool.query('DELETE FROM productos WHERE id = $1', [id]);
    res.json({ mensaje: 'Producto eliminado correctamente' });
  } catch (error) {
    console.error('Error eliminando producto:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarProductosTienda,
  listarCategorias,
  crearProducto,
  editarProducto,
  toggleDisponible,
  eliminarProducto,
};