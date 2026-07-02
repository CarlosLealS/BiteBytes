const pool        = require('../config/db');
const bcrypt      = require('bcrypt');
const crypto      = require('crypto');
const transporter = require('../config/mailer');

// GET /api/tienda/:id
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

// GET /api/tienda/:id/productos-disponibles
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

// GET /api/tienda/:id/publicaciones-activas
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

// POST /api/tienda/:id/resenias
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

// GET /api/tienda/:id/mi-resenia
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

// GET /api/favoritos
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

// POST /api/favoritos/:productoId
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

// DELETE /api/favoritos/:productoId
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

// GET /api/favoritos/ids
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
    console.error('Error listando trabajadores:', err.message);
    res.status(500).json({ error: 'Error al obtener trabajadores' });
  }
};

// POST /api/tienda/:id/trabajadores
const crearTrabajador = async (req, res) => {
  const { id } = req.params;
  const { nombre, email, password } = req.body;

  if (!nombre || !email || !password) {
    return res.status(400).json({ error: 'Nombre, email y password son requeridos' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tienda = await client.query(
      'SELECT id FROM tiendas WHERE id = $1 AND duenio_id = $2',
      [id, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    const existe = await client.query(
      'SELECT id FROM usuarios WHERE email = $1', [email]
    );
    if (existe.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'El email ya está registrado' });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const usuario = await client.query(
      `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
       VALUES ($1, $2, $3, 4)
       RETURNING id, nombre, email, activo, creado_en`,
      [nombre, email, password_hash]
    );

    const nuevoUsuario = usuario.rows[0];

    const trabajador = await client.query(
      `INSERT INTO trabajadores_tienda (usuario_id, tienda_id)
       VALUES ($1, $2)
       RETURNING id AS trabajador_id, desde`,
      [nuevoUsuario.id, id]
    );

    await client.query('COMMIT');
    res.status(201).json({ ...nuevoUsuario, ...trabajador.rows[0] });
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
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tienda = await client.query(
      'SELECT id FROM tiendas WHERE id = $1 AND duenio_id = $2',
      [tiendaId, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    // Obtener el usuario_id del trabajador antes de borrarlo
    const trabResult = await client.query(
      'DELETE FROM trabajadores_tienda WHERE id = $1 AND tienda_id = $2 RETURNING usuario_id',
      [trabajadorId, tiendaId]
    );

    if (trabResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Trabajador no encontrado' });
    }

    const usuarioId = trabResult.rows[0].usuario_id;

    // Eliminar también la cuenta del usuario (rol trabajador_tienda = rol_id 4)
    // Solo si no pertenece a otra tienda
    const otraTienda = await client.query(
      'SELECT 1 FROM trabajadores_tienda WHERE usuario_id = $1 LIMIT 1',
      [usuarioId]
    );
    if (otraTienda.rows.length === 0) {
      await client.query(
        'DELETE FROM usuarios WHERE id = $1 AND rol_id = 4',
        [usuarioId]
      );
    }

    await client.query('COMMIT');
    res.json({ mensaje: 'Trabajador eliminado de la tienda correctamente' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error eliminando trabajador:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// POST /api/tienda/:id/invitar-trabajador
const invitarTrabajador = async (req, res) => {
  const { id } = req.params;
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  try {
    const tienda = await pool.query(
      'SELECT id, nombre FROM tiendas WHERE id = $1 AND duenio_id = $2',
      [id, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    const nombreTienda = tienda.rows[0].nombre;

    const usuarioExiste = await pool.query(
      'SELECT id FROM usuarios WHERE email = $1', [email]
    );
    if (usuarioExiste.rows.length > 0) {
      return res.status(409).json({ error: 'El email ya tiene una cuenta registrada' });
    }

    // Eliminar invitación previa si existe
    await pool.query(
      'DELETE FROM invitaciones_trabajador WHERE email = $1 AND tienda_id = $2',
      [email, id]
    );

    const token = crypto.randomBytes(32).toString('hex');

    await pool.query(
      `INSERT INTO invitaciones_trabajador (email, tienda_id, token)
       VALUES ($1, $2, $3)`,
      [email, id, token]
    );

    const urlRegistro = `${process.env.FRONTEND_URL}/registro-trabajador?token=${token}`;

    await transporter.sendMail({
      from:    `"BiteBytes" <${process.env.GMAIL_USER}>`,
      to:      email,
      subject: `Invitación para unirte a ${nombreTienda} en BiteBytes`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #f4f6fb; border-radius: 12px;">
          <h2 style="color: #0B1F5C; margin-bottom: 8px;">¡Te han invitado a BiteBytes!</h2>
          <p style="color: #374151; font-size: 15px;">
            Has sido invitado a unirte como trabajador de <strong>${nombreTienda}</strong>.
          </p>
          <p style="color: #374151; font-size: 15px;">
            Haz click en el botón para completar tu registro:
          </p>
          <a href="${urlRegistro}"
             style="display: inline-block; margin: 20px 0; padding: 12px 28px;
                    background: #F5A623; color: #0B1F5C; font-weight: bold;
                    border-radius: 8px; text-decoration: none; font-size: 15px;">
            Completar registro
          </a>
          <p style="color: #9CA3AF; font-size: 12px; margin-top: 24px;">
            Este enlace expira en 48 horas. Si no esperabas esta invitación, ignora este correo.
          </p>
        </div>
      `,
    });

    res.json({ mensaje: `Invitación enviada a ${email}` });
  } catch (error) {
    console.error('Error enviando invitación:', error.message);
    res.status(500).json({ error: 'Error al enviar la invitación' });
  }
};

// POST /api/registro-trabajador
const registrarTrabajador = async (req, res) => {
  const { token, nombre, password } = req.body;

  if (!token || !nombre || !password) {
    return res.status(400).json({ error: 'Token, nombre y password son requeridos' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const invitacion = await client.query(
      `SELECT * FROM invitaciones_trabajador
       WHERE token = $1 AND usado = false AND expira_en > NOW()`,
      [token]
    );
    if (invitacion.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'El enlace es inválido o ha expirado' });
    }

    const { email, tienda_id } = invitacion.rows[0];

    const existe = await client.query(
      'SELECT id FROM usuarios WHERE email = $1', [email]
    );
    if (existe.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'El email ya tiene una cuenta registrada' });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const usuario = await client.query(
      `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
       VALUES ($1, $2, $3, 4)
       RETURNING id, nombre, email`,
      [nombre, email, password_hash]
    );

    await client.query(
      `INSERT INTO trabajadores_tienda (usuario_id, tienda_id)
       VALUES ($1, $2)`,
      [usuario.rows[0].id, tienda_id]
    );

    await client.query(
      'UPDATE invitaciones_trabajador SET usado = true WHERE token = $1',
      [token]
    );

    await client.query('COMMIT');

    res.status(201).json({
      mensaje: 'Cuenta creada correctamente. Ya puedes iniciar sesión.',
      usuario: usuario.rows[0],
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error registrando trabajador:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// GET /api/tienda/:id/todas-resenias
const obtenerTodasLasResenias = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT 'tienda' AS tipo_resenia, r.id AS resenia_id, r.calificacion, r.comentario, r.creado_en, u.nombre AS usuario_nombre, u.id AS usuario_id
       FROM resenias_tienda r JOIN usuarios u ON u.id = r.usuario_id WHERE r.tienda_id = $1
       UNION ALL
       SELECT 'producto' AS tipo_resenia, r.id AS resenia_id, r.calificacion, r.comentario, r.creado_en, u.nombre AS usuario_nombre, u.id AS usuario_id
       FROM resenias r JOIN usuarios u ON u.id = r.usuario_id JOIN productos p ON p.id = r.producto_id WHERE p.tienda_id = $1
       UNION ALL
       SELECT 'publicacion' AS tipo_resenia, r.id AS resenia_id, r.calificacion, r.comentario, r.creado_en, u.nombre AS usuario_nombre, u.id AS usuario_id
       FROM resenias_publicacion r JOIN usuarios u ON u.id = r.usuario_id JOIN publicaciones p ON p.id = r.publicacion_id WHERE p.tienda_id = $1
       UNION ALL
       SELECT 'plato' AS tipo_resenia, r.id AS resenia_id, r.calificacion, r.comentario, r.creado_en, u.nombre AS usuario_nombre, u.id AS usuario_id
       FROM resenias_platos r JOIN usuarios u ON u.id = r.usuario_id JOIN menu_casino_platos mcp ON mcp.id = r.plato_id JOIN menu_casino mc ON mc.id = mcp.menu_id WHERE mc.tienda_id = $1
       ORDER BY creado_en DESC`,
      [id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error obteniendo todas las reseñas:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/tienda/reportar-resenia
const reportarResenia = async (req, res) => {
  const { resenia_id, tipo_resenia, motivo } = req.body;
  if (!resenia_id || !tipo_resenia || !motivo) {
    return res.status(400).json({ error: 'Faltan datos para el reporte' });
  }
  try {
    await pool.query(
      `INSERT INTO reportes_resenia (resenia_id, tipo_resenia, reportador_id, motivo)
       VALUES ($1, $2, $3, $4)`,
      [resenia_id, tipo_resenia, req.usuario.id, motivo]
    );
    res.status(201).json({ mensaje: 'Reporte enviado con éxito' });
  } catch (error) {
    console.error('Error reportando reseña:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// PUT /api/tienda/:id
const actualizarTienda = async (req, res) => {
  const { id } = req.params;
  const { nombre, descripcion, horario, imagen_url } = req.body;

  if (!nombre) {
    return res.status(400).json({ error: 'El nombre es requerido' });
  }

  try {
    const check = await pool.query(
      `SELECT t.id FROM tiendas t 
       WHERE t.id = $1 AND (
         t.duenio_id = $2
         OR EXISTS (SELECT 1 FROM trabajadores_tienda tt WHERE tt.tienda_id = t.id AND tt.usuario_id = $2)
       )`,
      [id, req.usuario.id]
    );
    
    if (check.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para editar esta tienda' });
    }

    const result = await pool.query(
      `UPDATE tiendas 
       SET nombre = $1, descripcion = $2, horario = $3, imagen_url = $4
       WHERE id = $5
       RETURNING *`,
      [nombre, descripcion || null, horario || null, imagen_url || null, id]
    );

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error actualizando tienda:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
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
  crearTrabajador,
  eliminarTrabajador,
  invitarTrabajador,
  registrarTrabajador,
  obtenerTodasLasResenias,
  reportarResenia,
  actualizarTienda,
};