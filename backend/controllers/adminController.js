const pool        = require('../config/db');
const bcrypt      = require('bcrypt');
const crypto      = require('crypto');
const transporter = require('../config/mailer');

// GET /api/admin/tiendas
const listarTiendas = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT t.id, t.nombre, t.descripcion, t.activa, tt.nombre AS tipo, tt.es_casino, 
              u.id AS duenio_id, u.nombre AS duenio_nombre, u.email AS duenio_email
       FROM tiendas t
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       JOIN usuarios u ON u.id = t.duenio_id
       ORDER BY t.creado_en DESC`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando tiendas admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/admin/tiendas — enviar invitación por email al futuro dueño
const invitarDuenio = async (req, res) => {
  const { email, tipo_tienda_id } = req.body;

  if (!email || !tipo_tienda_id) {
    return res.status(400).json({ error: 'Email y tipo de tienda son requeridos' });
  }

  try {
    // Verificar que el tipo de tienda existe
    const tipo = await pool.query('SELECT id, nombre FROM tipo_tienda WHERE id = $1', [tipo_tienda_id]);
    if (tipo.rows.length === 0) {
      return res.status(400).json({ error: 'Tipo de tienda inválido' });
    }
    const nombreTipo = tipo.rows[0].nombre;

    // Verificar que el email no tiene ya una cuenta
    const existe = await pool.query('SELECT id FROM usuarios WHERE email = $1', [email]);
    if (existe.rows.length > 0) {
      return res.status(409).json({ error: 'Este email ya tiene una cuenta registrada' });
    }

    // Eliminar invitación previa si existe
    await pool.query(
      'DELETE FROM invitaciones_duenio WHERE email = $1',
      [email]
    );

    const token = crypto.randomBytes(32).toString('hex');

    await pool.query(
      `INSERT INTO invitaciones_duenio (email, tipo_tienda_id, token)
       VALUES ($1, $2, $3)`,
      [email, tipo_tienda_id, token]
    );

    const urlRegistro = `${process.env.FRONTEND_URL}/registro-duenio?token=${token}`;

    await transporter.sendMail({
      from:    `"BiteBytes" <${process.env.GMAIL_USER}>`,
      to:      email,
      subject: `Invitación para registrar tu tienda en BiteBytes`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #f4f6fb; border-radius: 12px;">
          <h2 style="color: #0B1F5C; margin-bottom: 8px;">¡Bienvenido a BiteBytes!</h2>
          <p style="color: #374151; font-size: 15px;">
            Has sido invitado a registrar tu tienda de tipo <strong>${nombreTipo}</strong> en la plataforma BiteBytes.
          </p>
          <p style="color: #374151; font-size: 15px;">
            Haz click en el botón para completar tu registro y configurar tu tienda:
          </p>
          <a href="${urlRegistro}"
             style="display: inline-block; margin: 20px 0; padding: 12px 28px;
                    background: #F5A623; color: #0B1F5C; font-weight: bold;
                    border-radius: 8px; text-decoration: none; font-size: 15px;">
            Registrar mi tienda
          </a>
          <p style="color: #9CA3AF; font-size: 12px; margin-top: 24px;">
            Este enlace expira en 48 horas. Si no esperabas esta invitación, ignora este correo.
          </p>
        </div>
      `,
    });

    res.json({ mensaje: `Invitación enviada a ${email}` });
  } catch (error) {
    console.error('Error enviando invitación dueño:', error.message);
    res.status(500).json({ error: 'Error al enviar la invitación' });
  }
};

// DELETE /api/admin/tiendas/:id
const eliminarTienda = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('DELETE FROM tiendas WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tienda no encontrada' });
    }
    res.json({ mensaje: 'Tienda eliminada correctamente' });
  } catch (error) {
    console.error('Error eliminando tienda admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/admin/trabajadores
const listarTrabajadores = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT tt.id AS trabajador_id, tt.desde, u.id AS usuario_id, u.nombre, u.email, u.activo, 
              t.id AS tienda_id, t.nombre AS tienda_nombre
       FROM trabajadores_tienda tt
       JOIN usuarios u ON u.id = tt.usuario_id
       JOIN tiendas t ON t.id = tt.tienda_id
       ORDER BY t.nombre, u.nombre`
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando trabajadores admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/admin/trabajadores
const crearTrabajador = async (req, res) => {
  const { tienda_id, nombre, email, password } = req.body;

  if (!tienda_id || !nombre || !email || !password) {
    return res.status(400).json({ error: 'Faltan datos obligatorios' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const existe = await client.query('SELECT id FROM usuarios WHERE email = $1', [email]);
    if (existe.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'El email ya está registrado' });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const usuario = await client.query(
      `INSERT INTO usuarios (nombre, email, password_hash, rol_id)
       VALUES ($1, $2, $3, 4)
       RETURNING id, nombre, email`,
      [nombre, email, password_hash]
    );

    const trabajador = await client.query(
      `INSERT INTO trabajadores_tienda (usuario_id, tienda_id)
       VALUES ($1, $2)
       RETURNING id AS trabajador_id, desde`,
      [usuario.rows[0].id, tienda_id]
    );

    await client.query('COMMIT');
    res.status(201).json({ mensaje: 'Trabajador creado exitosamente', trabajador: { ...usuario.rows[0], ...trabajador.rows[0] } });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creando trabajador admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// DELETE /api/admin/trabajadores/:id
const eliminarTrabajador = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('DELETE FROM trabajadores_tienda WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Trabajador no encontrado' });
    }
    res.json({ mensaje: 'Trabajador eliminado correctamente' });
  } catch (error) {
    console.error('Error eliminando trabajador admin:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/admin/usuarios/:id/resetear-contrasena
const enviarReseteoContrasena = async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      `SELECT u.id, u.nombre, u.email, r.nombre AS rol
       FROM usuarios u
       JOIN roles r ON r.id = u.rol_id
       WHERE u.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    const usuario = result.rows[0];

    // Invalidar tokens anteriores
    await pool.query(
      'UPDATE reset_password_tokens SET usado = true WHERE usuario_id = $1 AND usado = false',
      [id]
    );

    const token = crypto.randomBytes(32).toString('hex');

    await pool.query(
      `INSERT INTO reset_password_tokens (usuario_id, token)
       VALUES ($1, $2)`,
      [id, token]
    );

    const urlReset = `${process.env.FRONTEND_URL}/resetear-contrasena?token=${token}`;

    await transporter.sendMail({
      from:    `"BiteBytes" <${process.env.GMAIL_USER}>`,
      to:      usuario.email,
      subject: `Restablece tu contraseña en BiteBytes`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #f4f6fb; border-radius: 12px;">
          <h2 style="color: #0B1F5C; margin-bottom: 8px;">Restablecer contraseña</h2>
          <p style="color: #374151; font-size: 15px;">
            Hola <strong>${usuario.nombre}</strong>, el administrador de BiteBytes ha solicitado el restablecimiento de tu contraseña.
          </p>
          <p style="color: #374151; font-size: 15px;">
            Haz click en el botón para crear una nueva contraseña:
          </p>
          <a href="${urlReset}"
             style="display: inline-block; margin: 20px 0; padding: 12px 28px;
                    background: #0B1F5C; color: white; font-weight: bold;
                    border-radius: 8px; text-decoration: none; font-size: 15px;">
            Cambiar contraseña
          </a>
          <p style="color: #9CA3AF; font-size: 12px; margin-top: 24px;">
            Este enlace expira en 1 hora. Si no esperabas este correo, ignóralo.
          </p>
        </div>
      `,
    });

    res.json({ mensaje: `Correo de restablecimiento enviado a ${usuario.email}` });
  } catch (error) {
    console.error('Error enviando reseteo contraseña:', error.message);
    res.status(500).json({ error: 'Error al enviar el correo' });
  }
};

// GET /api/admin/reportes
const listarReportes = async (req, res) => {
  try {
    const query = `
      SELECT rr.id AS reporte_id, rr.tipo_resenia, rr.resenia_id, rr.motivo, rr.estado, rr.creado_en AS reporte_creado_en,
             rep.nombre AS reportador_nombre, rep.email AS reportador_email,
             COALESCE(rt.comentario, r.comentario, rp.comentario, rpl.comentario) AS comentario_texto,
             COALESCE(rt.usuario_id, r.usuario_id, rp.usuario_id, rpl.usuario_id) AS autor_id,
             aut.nombre AS autor_nombre, aut.email AS autor_email
      FROM reportes_resenia rr
      JOIN usuarios rep ON rep.id = rr.reportador_id
      LEFT JOIN resenias_tienda rt ON rr.tipo_resenia = 'tienda' AND rt.id = rr.resenia_id
      LEFT JOIN resenias r ON rr.tipo_resenia = 'producto' AND r.id = rr.resenia_id
      LEFT JOIN resenias_publicacion rp ON rr.tipo_resenia = 'publicacion' AND rp.id = rr.resenia_id
      LEFT JOIN resenias_platos rpl ON rr.tipo_resenia = 'plato' AND rpl.id = rr.resenia_id
      LEFT JOIN usuarios aut ON aut.id = COALESCE(rt.usuario_id, r.usuario_id, rp.usuario_id, rpl.usuario_id)
      WHERE rr.estado = 'pendiente'
      ORDER BY rr.creado_en ASC
    `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (error) {
    console.error('Error listando reportes:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/admin/reportes/:id/resolver
const resolverReporte = async (req, res) => {
  const { id } = req.params;
  const { accion, dias_sancion, motivo_sancion } = req.body;
  if (!['sancionar', 'descartar'].includes(accion)) {
    return res.status(400).json({ error: 'Acción inválida' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const reporteRes = await client.query('SELECT * FROM reportes_resenia WHERE id = $1', [id]);
    if (reporteRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Reporte no encontrado' });
    }
    const reporte = reporteRes.rows[0];

    if (accion === 'descartar') {
      await client.query('UPDATE reportes_resenia SET estado = $1 WHERE id = $2', ['descartado', id]);
    } else if (accion === 'sancionar') {
      let tabla = '';
      if (reporte.tipo_resenia === 'tienda') tabla = 'resenias_tienda';
      else if (reporte.tipo_resenia === 'producto') tabla = 'resenias';
      else if (reporte.tipo_resenia === 'publicacion') tabla = 'resenias_publicacion';
      else if (reporte.tipo_resenia === 'plato') tabla = 'resenias_platos';

      const reseniaEliminada = await client.query(`DELETE FROM ${tabla} WHERE id = $1 RETURNING usuario_id`, [reporte.resenia_id]);
      
      if (reseniaEliminada.rows.length > 0) {
        const autor_id = reseniaEliminada.rows[0].usuario_id;
        
        let finSancion = null;
        if (dias_sancion && parseInt(dias_sancion) > 0) {
           finSancion = new Date();
           finSancion.setDate(finSancion.getDate() + parseInt(dias_sancion));
        }
        
        await client.query(
          `INSERT INTO sanciones (usuario_id, admin_id, motivo, fin) VALUES ($1, $2, $3, $4)`,
          [autor_id, req.usuario.id, motivo_sancion || 'Infracción de normas', finSancion]
        );
      }
      
      await client.query('UPDATE reportes_resenia SET estado = $1 WHERE id = $2', ['sancionado', id]);
    }

    await client.query('COMMIT');
    res.json({ mensaje: 'Reporte resuelto correctamente' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error resolviendo reporte:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

module.exports = {
  listarTiendas,
  invitarDuenio,
  eliminarTienda,
  listarTrabajadores,
  crearTrabajador,
  eliminarTrabajador,
  enviarReseteoContrasena,
  listarReportes,
  resolverReporte,
};
