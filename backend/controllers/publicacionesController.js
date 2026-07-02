const pool       = require('../config/db');
const cloudinary = require('../config/cloudinary');

// GET /api/tienda/:id/publicaciones
const listarPublicaciones = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT p.*,
              JSON_AGG(
                JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'imagen_public_id', pi.imagen_public_id, 'orden', pi.orden)
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
  const { tienda_id, nombre, descripcion, precio_oferta, publicar_en, expira_en, activa, es_oferta, imagenes, productosIds } = req.body;
  // imagenes: [{ url, public_id }, ...]
  // productosIds: [uuid1, uuid2, ...]

  if (!nombre || !tienda_id) {
    return res.status(400).json({ error: 'Nombre y tienda_id son requeridos' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tienda = await client.query(
      `SELECT t.id FROM tiendas t 
       WHERE t.id = $1 AND (
         t.duenio_id = $2
         OR EXISTS (SELECT 1 FROM trabajadores_tienda tt WHERE tt.tienda_id = t.id AND tt.usuario_id = $2)
       )`,
      [tienda_id, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    const result = await client.query(
      `INSERT INTO publicaciones (tienda_id, nombre, descripcion, precio_oferta, publicar_en, expira_en, activa, es_oferta)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [tienda_id, nombre, descripcion || null, precio_oferta || null,
       publicar_en || new Date(), expira_en || null, activa ?? true, es_oferta ?? false]
    );

    const publicacion = result.rows[0];

    if (imagenes && imagenes.length > 0) {
      for (let i = 0; i < imagenes.length; i++) {
        const img = imagenes[i];
        // Acepta tanto string (solo url) como objeto { url, public_id }
        const url       = typeof img === 'string' ? img : img.url;
        const public_id = typeof img === 'string' ? null : img.public_id;
        await client.query(
          `INSERT INTO publicacion_imagenes (publicacion_id, imagen_url, imagen_public_id, orden)
           VALUES ($1, $2, $3, $4)`,
          [publicacion.id, url, public_id || null, i]
        );
      }
    }

    // Insertar productos asociados
    if (productosIds && Array.isArray(productosIds) && productosIds.length > 0) {
      for (const prodId of productosIds) {
        await client.query(
          `INSERT INTO publicacion_productos (publicacion_id, producto_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [publicacion.id, prodId]
        );
      }

      // Lógica de notificaciones
      if (es_oferta) {
        const favs = await client.query(
          `SELECT DISTINCT usuario_id, p.nombre AS producto_nombre
           FROM favoritos f
           JOIN productos p ON p.id = f.producto_id
           WHERE f.producto_id = ANY($1::uuid[]) AND f.usuario_id != $2`,
          [productosIds, req.usuario.id]
        );

        if (favs.rows.length > 0) {
          const tiendaData = await client.query('SELECT nombre FROM tiendas WHERE id = $1', [tienda_id]);
          const nombreTienda = tiendaData.rows[0]?.nombre || 'una tienda';

          for (const fav of favs.rows) {
            const titulo = '¡Oferta en tu favorito!';
            const mensaje = `El producto "${fav.producto_nombre}" que marcaste como favorito está en oferta en ${nombreTienda}.`;
            await client.query(
              `INSERT INTO notificaciones (usuario_id, titulo, mensaje, tipo, referencia_id)
               VALUES ($1, $2, $3, 'oferta', $4)`,
              [fav.usuario_id, titulo, mensaje, publicacion.id]
            );
          }
        }
      }
    }

    await client.query('COMMIT');

    const completa = await pool.query(
      `SELECT p.*,
              (
                SELECT JSON_AGG(
                  JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                  ORDER BY pi.orden
                )
                FROM publicacion_imagenes pi WHERE pi.publicacion_id = p.id
              ) AS imagenes,
              (
                SELECT COALESCE(JSON_AGG(pp.producto_id), '[]'::json)
                FROM publicacion_productos pp WHERE pp.publicacion_id = p.id
              ) AS productos_ids
       FROM publicaciones p
       WHERE p.id = $1`,
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
  const { nombre, descripcion, precio_oferta, publicar_en, expira_en, activa, es_oferta, imagenes, productosIds } = req.body;

  if (!nombre) {
    return res.status(400).json({ error: 'Nombre es requerido' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const check = await client.query(
      `SELECT p.id FROM publicaciones p
       JOIN tiendas t ON t.id = p.tienda_id
       WHERE p.id = $1 AND (
         t.duenio_id = $2
         OR EXISTS (SELECT 1 FROM trabajadores_tienda tt WHERE tt.tienda_id = t.id AND tt.usuario_id = $2)
       )`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para editar esta publicación' });
    }

    await client.query(
      `UPDATE publicaciones
       SET nombre = $1, descripcion = $2, precio_oferta = $3,
           publicar_en = $4, expira_en = $5, activa = $6, es_oferta = $7, actualizado_en = NOW()
       WHERE id = $8`,
      [nombre, descripcion || null, precio_oferta || null,
       publicar_en, expira_en || null, activa ?? true, es_oferta ?? false, id]
    );

    // Eliminar imágenes anteriores de Cloudinary
    const imagenesAnteriores = await client.query(
      'SELECT imagen_public_id FROM publicacion_imagenes WHERE publicacion_id = $1',
      [id]
    );
    for (const row of imagenesAnteriores.rows) {
      if (row.imagen_public_id) {
        await cloudinary.uploader.destroy(row.imagen_public_id).catch(console.error);
      }
    }

    await client.query('DELETE FROM publicacion_imagenes WHERE publicacion_id = $1', [id]);

    if (imagenes && imagenes.length > 0) {
      for (let i = 0; i < imagenes.length; i++) {
        const img       = imagenes[i];
        const url       = typeof img === 'string' ? img : img.url;
        const public_id = typeof img === 'string' ? null : img.public_id;
        await client.query(
          `INSERT INTO publicacion_imagenes (publicacion_id, imagen_url, imagen_public_id, orden)
           VALUES ($1, $2, $3, $4)`,
          [id, url, public_id || null, i]
        );
      }
    }

    // Actualizar productos asociados
    await client.query('DELETE FROM publicacion_productos WHERE publicacion_id = $1', [id]);
    if (productosIds && Array.isArray(productosIds) && productosIds.length > 0) {
      for (const prodId of productosIds) {
        await client.query(
          `INSERT INTO publicacion_productos (publicacion_id, producto_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [id, prodId]
        );
      }

      if (es_oferta) {
        const favs = await client.query(
          `SELECT DISTINCT usuario_id, p.nombre AS producto_nombre
           FROM favoritos f
           JOIN productos p ON p.id = f.producto_id
           WHERE f.producto_id = ANY($1::uuid[]) AND f.usuario_id != $2`,
          [productosIds, req.usuario.id]
        );

        if (favs.rows.length > 0) {
          const pubData = await client.query('SELECT tienda_id FROM publicaciones WHERE id = $1', [id]);
          const tId = pubData.rows[0].tienda_id;
          const tiendaData = await client.query('SELECT nombre FROM tiendas WHERE id = $1', [tId]);
          const nombreTienda = tiendaData.rows[0]?.nombre || 'una tienda';

          for (const fav of favs.rows) {
            const notifExiste = await client.query(
              `SELECT id FROM notificaciones 
               WHERE usuario_id = $1 AND referencia_id = $2 AND tipo = 'oferta' 
               AND creado_en > NOW() - INTERVAL '1 day'`,
              [fav.usuario_id, id]
            );

            if (notifExiste.rows.length === 0) {
              const titulo = '¡Oferta en tu favorito!';
              const mensaje = `El producto "${fav.producto_nombre}" que marcaste como favorito está en oferta en ${nombreTienda}.`;
              await client.query(
                `INSERT INTO notificaciones (usuario_id, titulo, mensaje, tipo, referencia_id)
                 VALUES ($1, $2, $3, 'oferta', $4)`,
                [fav.usuario_id, titulo, mensaje, id]
              );
            }
          }
        }
      }
    }

    await client.query('COMMIT');

    const completa = await pool.query(
      `SELECT p.*,
              (
                SELECT JSON_AGG(
                  JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                  ORDER BY pi.orden
                )
                FROM publicacion_imagenes pi WHERE pi.publicacion_id = p.id
              ) AS imagenes,
              (
                SELECT COALESCE(JSON_AGG(pp.producto_id), '[]'::json)
                FROM publicacion_productos pp WHERE pp.publicacion_id = p.id
              ) AS productos_ids
       FROM publicaciones p
       WHERE p.id = $1`,
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
       WHERE p.id = $1 AND (
         t.duenio_id = $2
         OR EXISTS (SELECT 1 FROM trabajadores_tienda tt WHERE tt.tienda_id = t.id AND tt.usuario_id = $2)
       )`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para eliminar esta publicación' });
    }

    // Eliminar imágenes de Cloudinary
    const imagenes = await pool.query(
      'SELECT imagen_public_id FROM publicacion_imagenes WHERE publicacion_id = $1',
      [id]
    );
    for (const row of imagenes.rows) {
      if (row.imagen_public_id) {
        await cloudinary.uploader.destroy(row.imagen_public_id).catch(console.error);
      }
    }

    await pool.query('DELETE FROM publicaciones WHERE id = $1', [id]);
    // Las tablas publicacion_productos y notificaciones asumen cascada, si no, habría que borrarlas
    // Pero como notificaciones no tiene FK en referencia_id o es_cascade, no rompe.
    res.json({ mensaje: 'Publicación eliminada correctamente' });
  } catch (error) {
    console.error('Error eliminando publicación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/publicaciones/activas
const obtenerPublicacionesActivas = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.*,
              t.nombre AS tienda_nombre,
              COALESCE(
                JSON_AGG(
                  JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                  ORDER BY pi.orden
                ) FILTER (WHERE pi.id IS NOT NULL),
                '[]'::json
              ) AS imagenes
       FROM publicaciones p
       JOIN tiendas t ON t.id = p.tienda_id
       LEFT JOIN publicacion_imagenes pi ON pi.publicacion_id = p.id
       WHERE p.activa = true
         AND t.activa = true
         AND p.publicar_en <= NOW()
         AND (p.expira_en IS NULL OR p.expira_en > NOW())
       GROUP BY p.id, t.id
       ORDER BY p.publicar_en DESC`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error obteniendo publicaciones activas:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/publicaciones/ofertas
const listarOfertas = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.*,
              t.nombre AS tienda_nombre, t.id AS tienda_id,
              COALESCE(
                JSON_AGG(
                  JSON_BUILD_OBJECT('id', pi.id, 'imagen_url', pi.imagen_url, 'orden', pi.orden)
                  ORDER BY pi.orden
                ) FILTER (WHERE pi.id IS NOT NULL),
                '[]'::json
              ) AS imagenes
       FROM publicaciones p
       JOIN tiendas t ON t.id = p.tienda_id
       LEFT JOIN publicacion_imagenes pi ON pi.publicacion_id = p.id
       WHERE p.activa = true
         AND p.es_oferta = true
         AND t.activa = true
         AND p.publicar_en <= NOW()
         AND (p.expira_en IS NULL OR p.expira_en > NOW())
       GROUP BY p.id, t.id
       ORDER BY p.publicar_en DESC`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando ofertas:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// ── Reseñas de publicaciones ────────────────────────────────────────────────

// GET /api/publicacion/:id/resenias
const listarReseniasPublicacion = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT r.*, u.nombre AS usuario_nombre
       FROM resenias_publicacion r
       JOIN usuarios u ON u.id = r.usuario_id
       WHERE r.publicacion_id = $1
       ORDER BY r.creado_en DESC
       LIMIT 20`,
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando reseñas de publicación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/publicacion/:id/resenias
const crearReseniaPublicacion = async (req, res) => {
  const { id } = req.params;
  const { calificacion, comentario } = req.body;

  if (!calificacion || calificacion < 1 || calificacion > 5) {
    return res.status(400).json({ error: 'Calificación debe ser entre 1 y 5' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO resenias_publicacion (usuario_id, publicacion_id, calificacion, comentario)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (usuario_id, publicacion_id)
       DO UPDATE SET calificacion = $3, comentario = $4, creado_en = NOW()
       RETURNING *`,
      [req.usuario.id, id, calificacion, comentario || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creando reseña de publicación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/publicacion/:id/mi-resenia
const miReseniaPublicacion = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT * FROM resenias_publicacion
       WHERE publicacion_id = $1 AND usuario_id = $2`,
      [id, req.usuario.id]
    );
    res.json(result.rows[0] || null);
  } catch (error) {
    console.error('Error obteniendo mi reseña de publicación:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarPublicaciones,
  obtenerPublicacionesActivas,
  listarOfertas,
  crearPublicacion,
  editarPublicacion,
  eliminarPublicacion,
  listarReseniasPublicacion,
  crearReseniaPublicacion,
  miReseniaPublicacion,
};