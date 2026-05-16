const pool = require('../config/db');

// GET /api/menu-casino/hoy (público - para alumnos)
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

// GET /api/menu-casino/tienda/:id (dueño casino)
const listarMenusCasino = async (req, res) => {
  const { id } = req.params;
  try {
    const tienda = await pool.query(
      `SELECT t.id FROM tiendas t
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       WHERE t.id = $1 AND t.duenio_id = $2 AND tt.es_casino = true`,
      [id, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    const menus = await pool.query(
      `SELECT * FROM menu_casino WHERE tienda_id = $1 ORDER BY fecha DESC`,
      [id]
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
    console.error('Error listando menús casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/menu-casino
const crearMenuCasino = async (req, res) => {
  const { tienda_id, fecha, nombre, descripcion, platos } = req.body;

  if (!tienda_id || !fecha || !nombre) {
    return res.status(400).json({ error: 'tienda_id, fecha y nombre son requeridos' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tienda = await client.query(
      `SELECT t.id FROM tiendas t
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       WHERE t.id = $1 AND t.duenio_id = $2 AND tt.es_casino = true`,
      [tienda_id, req.usuario.id]
    );
    if (tienda.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }

    const menuResult = await client.query(
      `INSERT INTO menu_casino (tienda_id, fecha, nombre, descripcion)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [tienda_id, fecha, nombre, descripcion || null]
    );
    const menu = menuResult.rows[0];

    if (platos && platos.length > 0) {
      for (let i = 0; i < platos.length; i++) {
        const p = platos[i];
        await client.query(
          `INSERT INTO menu_casino_platos (menu_id, nombre, descripcion, imagen_url, precio, etiqueta, orden)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [menu.id, p.nombre, p.descripcion || null, p.imagen_url || null, p.precio || null, p.etiqueta || null, i]
        );
      }
    }

    await client.query('COMMIT');

    const platosResult = await pool.query(
      `SELECT * FROM menu_casino_platos WHERE menu_id = $1 ORDER BY orden`,
      [menu.id]
    );
    res.status(201).json({ ...menu, platos: platosResult.rows });
  } catch (error) {
    await client.query('ROLLBACK');
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya existe un menú para esa fecha' });
    }
    console.error('Error creando menú casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// PUT /api/menu-casino/:id
const editarMenuCasino = async (req, res) => {
  const { id } = req.params;
  const { fecha, nombre, descripcion, platos } = req.body;

  if (!fecha || !nombre) {
    return res.status(400).json({ error: 'fecha y nombre son requeridos' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const check = await client.query(
      `SELECT mc.id FROM menu_casino mc
       JOIN tiendas t ON t.id = mc.tienda_id
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       WHERE mc.id = $1 AND t.duenio_id = $2 AND tt.es_casino = true`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'No tienes permiso para editar este menú' });
    }

    await client.query(
      `UPDATE menu_casino SET fecha = $1, nombre = $2, descripcion = $3 WHERE id = $4`,
      [fecha, nombre, descripcion || null, id]
    );

    await client.query('DELETE FROM menu_casino_platos WHERE menu_id = $1', [id]);
    if (platos && platos.length > 0) {
      for (let i = 0; i < platos.length; i++) {
        const p = platos[i];
        await client.query(
          `INSERT INTO menu_casino_platos (menu_id, nombre, descripcion, imagen_url, precio, etiqueta, orden)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [id, p.nombre, p.descripcion || null, p.imagen_url || null, p.precio || null, p.etiqueta || null, i]
        );
      }
    }

    await client.query('COMMIT');

    const platosResult = await pool.query(
      `SELECT * FROM menu_casino_platos WHERE menu_id = $1 ORDER BY orden`,
      [id]
    );
    const menuResult = await pool.query(`SELECT * FROM menu_casino WHERE id = $1`, [id]);
    res.json({ ...menuResult.rows[0], platos: platosResult.rows });
  } catch (error) {
    await client.query('ROLLBACK');
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya existe un menú para esa fecha' });
    }
    console.error('Error editando menú casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
};

// DELETE /api/menu-casino/:id
const eliminarMenuCasino = async (req, res) => {
  const { id } = req.params;
  try {
    const check = await pool.query(
      `SELECT mc.id FROM menu_casino mc
       JOIN tiendas t ON t.id = mc.tienda_id
       JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
       WHERE mc.id = $1 AND t.duenio_id = $2 AND tt.es_casino = true`,
      [id, req.usuario.id]
    );
    if (check.rows.length === 0) {
      return res.status(403).json({ error: 'No tienes permiso para eliminar este menú' });
    }
    await pool.query('DELETE FROM menu_casino WHERE id = $1', [id]);
    res.json({ mensaje: 'Menú eliminado correctamente' });
  } catch (error) {
    console.error('Error eliminando menú casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/menu-casino/platos/:id/resenias (alumno valora un plato)
const crearResenia = async (req, res) => {
  const { id } = req.params;
  const { calificacion, comentario } = req.body;

  if (!calificacion || calificacion < 1 || calificacion > 5) {
    return res.status(400).json({ error: 'Calificación debe ser entre 1 y 5' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO resenias_platos (usuario_id, plato_id, calificacion, comentario)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (usuario_id, plato_id)
       DO UPDATE SET calificacion = $3, comentario = $4
       RETURNING *`,
      [req.usuario.id, id, calificacion, comentario || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creando reseña plato:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarMenuCasinoHoy,
  listarMenusCasino,
  crearMenuCasino,
  editarMenuCasino,
  eliminarMenuCasino,
  crearResenia,
};