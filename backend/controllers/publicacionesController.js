const pool = require('../config/db');

// GET /api/tienda/:id/publicaciones
const listarPublicaciones = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT p.*,
              JSON_AGG(
                JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                ORDER BY pi.orden
              ) FILTER (WHERE pi.id IS NOT NULL) AS imagenes
       FROM publicaciones p
       LEFT JOIN publicacion_imagenes pi ON pi.publicacion_id = p.id
       WHERE p.tienda_id = $1
       GROUP BY p.id
       ORDER BY p.creado_en DESC`,
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando publicaciones:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/publicaciones
const crearPublicacion = async (req, res) => {
  const { tienda_id, nombre, descripcion, precio_oferta, publicar_en, expira_en, activa, imagenes } = req.body;

  if (!nombre || !tienda_id) {
    return res.status(400).json({ error: 'Nombre y tienda_id son requeridos' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Verificar que la tienda pertenece al dueño
    const tienda = await client.query(
      'SELECT id FROM tiendas WHERE id = $1 AND duenio_id = $2',
      [tienda_id, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    // Insertar publicación
    const result = await client.query(
      `INSERT INTO publicaciones (tienda_id, nombre, descripcion, precio_oferta, publicar_en, expira_en, activa)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        tienda_id,
        nombre,
        descripcion || null,
        precio_oferta || null,
        publicar_en || new Date(),
        expira_en || null,
        activa ?? true,
      ]
    );

    const publicacion = result.rows[0];

    // Insertar imágenes si hay
    if (imagenes && imagenes.length > 0) {
      for (let i = 0; i < imagenes.length; i++) {
        await client.query(
          `INSERT INTO publicacion_imagenes (publicacion_id, imagen_url, orden) VALUES ($1, $2, $3)`,
          [publicacion.id, imagenes[i], i]
        );
      }
    }

    await client.query('COMMIT');

    // Retornar publicación con imágenes
    const completa = await pool.query(
      `SELECT p.*,
              JSON_AGG(
                JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                ORDER BY pi.orden
              ) FILTER (WHERE pi.id IS NOT NULL) AS imagenes
       FROM publicaciones p
       LEFT JOIN publicacion_imagenes pi ON pi.publicacion_id = p.id
       WHERE p.id = $1
       GROUP BY p.id`,
      [publicacion.id]
    );

    res.status(201).json(completa.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creando publicación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// PUT /api/publicaciones/:id
const editarPublicacion = async (req, res) => {
  const { id } = req.params;
  const { nombre, descripcion, precio_oferta, publicar_en, expira_en, activa, imagenes } = req.body;

  if (!nombre) {
    return res.status(400).json({ error: 'Nombre es requerido' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Verificar permiso
    const check = await client.query(
      `SELECT p.id FROM publicaciones p
       JOIN tiendas t ON t.id = p.tienda_id
       WHERE p.id = $1 AND t.duenio_id = $2`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para editar esta publicación' });
    }

    // Actualizar publicación
    await client.query(
      `UPDATE publicaciones
       SET nombre = $1, descripcion = $2, precio_oferta = $3,
           publicar_en = $4, expira_en = $5, activa = $6, actualizado_en = NOW()
       WHERE id = $7`,
      [nombre, descripcion || null, precio_oferta || null, publicar_en, expira_en || null, activa ?? true, id]
    );

    // Reemplazar imágenes
    await client.query('DELETE FROM publicacion_imagenes WHERE publicacion_id = $1', [id]);
    if (imagenes && imagenes.length > 0) {
      for (let i = 0; i < imagenes.length; i++) {
        await client.query(
          `INSERT INTO publicacion_imagenes (publicacion_id, imagen_url, orden) VALUES ($1, $2, $3)`,
          [id, imagenes[i], i]
        );
      }
    }

    await client.query('COMMIT');

    // Retornar publicación actualizada con imágenes
    const completa = await pool.query(
      `SELECT p.*,
              JSON_AGG(
                JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                ORDER BY pi.orden
              ) FILTER (WHERE pi.id IS NOT NULL) AS imagenes
       FROM publicaciones p
       LEFT JOIN publicacion_imagenes pi ON pi.publicacion_id = p.id
       WHERE p.id = $1
       GROUP BY p.id`,
      [id]
    );

    res.json(completa.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error editando publicación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// DELETE /api/publicaciones/:id
const eliminarPublicacion = async (req, res) => {
  const { id } = req.params;
  try {
    const check = await pool.query(
      `SELECT p.id FROM publicaciones p
       JOIN tiendas t ON t.id = p.tienda_id
       WHERE p.id = $1 AND t.duenio_id = $2`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para eliminar esta publicación' });
    }

    // Las imágenes se eliminan en cascada por la FK
    await pool.query('DELETE FROM publicaciones WHERE id = $1', [id]);
    res.json({ mensaje: 'Publicación eliminada correctamente' });
  } catch (error) {
    console.error('Error eliminando publicación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarPublicaciones,
  crearPublicacion,
  editarPublicacion,
  eliminarPublicacion,
};