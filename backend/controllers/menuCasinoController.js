const pool   = require('../config/db');
const path   = require('path');
const fs     = require('fs');

// ─── Helper: adjunta platos a cada menú ────────────────────────────────────────
const _adjuntarPlatos = async (menus) => {
  if (!menus.length) return menus;
  const ids = menus.map((m) => m.id);
  const { rows } = await pool.query(
    `SELECT * FROM menu_casino_platos
     WHERE menu_id = ANY($1::uuid[])
     ORDER BY menu_id, orden ASC, creado_en ASC`,
    [ids]
  );
  const porMenu = {};
  rows.forEach((p) => {
    if (!porMenu[p.menu_id]) porMenu[p.menu_id] = [];
    porMenu[p.menu_id].push(p);
  });
  return menus.map((m) => ({ ...m, platos: porMenu[m.id] ?? [] }));
};

// ─── Helper: verificar propiedad del menú ─────────────────────────────────────
const _verificarDuenio = async (menuId, usuarioId) => {
  const { rows } = await pool.query(
    `SELECT mc.id FROM menu_casino mc
     JOIN tiendas t ON t.id = mc.tienda_id
     JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
     WHERE mc.id = $1 AND t.duenio_id = $2 AND tt.es_casino = true`,
    [menuId, usuarioId]
  );
  return rows.length > 0;
};

// ─── Helper: verificar propiedad de la tienda ─────────────────────────────────
const _verificarTienda = async (tiendaId, usuarioId) => {
  const { rows } = await pool.query(
    `SELECT t.id FROM tiendas t
     JOIN tipo_tienda tt ON tt.id = t.tipo_tienda_id
     WHERE t.id = $1 AND t.duenio_id = $2 AND tt.es_casino = true`,
    [tiendaId, usuarioId]
  );
  return rows.length > 0;
};

// ─── Helper: borrar imagen del disco ──────────────────────────────────────────
const _borrarImagen = (imagenUrl) => {
  if (!imagenUrl) return;
  try {
    const filename = path.basename(imagenUrl);
    const filepath = path.join(__dirname, '..', 'uploads', filename);
    if (fs.existsSync(filepath)) fs.unlinkSync(filepath);
  } catch (_) {}
};

// ══════════════════════════════════════════════════════════════════════════════
// MENÚ CASINO
// ══════════════════════════════════════════════════════════════════════════════

// GET /api/menu-casino/hoy  (alumnos)
const listarMenuCasinoHoy = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT mc.*, t.nombre AS tienda_nombre
       FROM menu_casino mc
       JOIN tiendas t ON t.id = mc.tienda_id
       WHERE mc.fecha = CURRENT_DATE AND t.activa = true
       ORDER BY t.nombre`
    );
    const menus = await _adjuntarPlatos(rows);
    res.json(menus);
  } catch (error) {
    console.error('Error listando menú casino hoy:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// GET /api/menu-casino/tienda/:id  (dueño)
const listarMenusCasino = async (req, res) => {
  const { id } = req.params;
  try {
    if (!(await _verificarTienda(id, req.usuario.id))) {
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }
    const { rows } = await pool.query(
      `SELECT * FROM menu_casino WHERE tienda_id = $1 ORDER BY fecha DESC`,
      [id]
    );
    const menus = await _adjuntarPlatos(rows);
    res.json(menus);
  } catch (error) {
    console.error('Error listando menús casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /api/menu-casino  (dueño)
const crearMenuCasino = async (req, res) => {
  const { tienda_id, fecha, precio } = req.body;
  if (!tienda_id || !fecha) {
    return res.status(400).json({ error: 'tienda_id y fecha son requeridos' });
  }
  try {
    if (!(await _verificarTienda(tienda_id, req.usuario.id))) {
      return res.status(403).json({ error: 'No tienes permiso para esta tienda' });
    }
    const { rows } = await pool.query(
      `INSERT INTO menu_casino (tienda_id, fecha, precio)
       VALUES ($1, $2, $3) RETURNING *`,
      [tienda_id, fecha, precio || null]
    );
    res.status(201).json({ ...rows[0], platos: [] });
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya existe un menú para esa fecha' });
    }
    console.error('Error creando menú casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// PUT /api/menu-casino/:id  (dueño) — solo actualiza fecha y precio
const editarMenuCasino = async (req, res) => {
  const { id } = req.params;
  const { fecha, precio } = req.body;
  if (!fecha) return res.status(400).json({ error: 'La fecha es requerida' });
  try {
    if (!(await _verificarDuenio(id, req.usuario.id))) {
      return res.status(403).json({ error: 'No tienes permiso para editar este menú' });
    }
    const { rows } = await pool.query(
      `UPDATE menu_casino SET fecha = $1, precio = $2 WHERE id = $3 RETURNING *`,
      [fecha, precio || null, id]
    );
    const menus = await _adjuntarPlatos(rows);
    res.json(menus[0]);
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya existe un menú para esa fecha' });
    }
    console.error('Error editando menú casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// DELETE /api/menu-casino/:id  (dueño)
const eliminarMenuCasino = async (req, res) => {
  const { id } = req.params;
  try {
    if (!(await _verificarDuenio(id, req.usuario.id))) {
      return res.status(403).json({ error: 'No tienes permiso para eliminar este menú' });
    }
    // Borrar imágenes de platos del disco
    const { rows: platos } = await pool.query(
      `SELECT imagen_url FROM menu_casino_platos WHERE menu_id = $1`, [id]
    );
    platos.forEach((p) => _borrarImagen(p.imagen_url));

    await pool.query('DELETE FROM menu_casino WHERE id = $1', [id]);
    res.json({ mensaje: 'Menú eliminado correctamente' });
  } catch (error) {
    console.error('Error eliminando menú casino:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// ══════════════════════════════════════════════════════════════════════════════
// PLATOS  (sub-recurso de menú)
// ══════════════════════════════════════════════════════════════════════════════

// POST /api/menu-casino/:menuId/platos
// Body: multipart/form-data  → nombre, descripcion?, orden?  + archivo "imagen"
const agregarPlato = async (req, res) => {
  const { menuId } = req.params;
  const { nombre, descripcion, orden } = req.body;

  if (!nombre?.trim()) {
    if (req.file) _borrarImagen(`/uploads/${req.file.filename}`);
    return res.status(400).json({ error: 'El nombre del plato es requerido' });
  }

  try {
    if (!(await _verificarDuenio(menuId, req.usuario.id))) {
      if (req.file) _borrarImagen(`/uploads/${req.file.filename}`);
      return res.status(403).json({ error: 'No tienes permiso para este menú' });
    }

    const imagenUrl = req.file
      ? `${process.env.BASE_URL || 'http://localhost:3000'}/uploads/${req.file.filename}`
      : null;

    const { rows } = await pool.query(
      `INSERT INTO menu_casino_platos (menu_id, nombre, descripcion, imagen_url, orden)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [menuId, nombre.trim(), descripcion?.trim() || null, imagenUrl, orden ?? 0]
    );
    res.status(201).json(rows[0]);
  } catch (error) {
    if (req.file) _borrarImagen(`/uploads/${req.file.filename}`);
    console.error('Error agregando plato:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// PUT /api/menu-casino/platos/:platoId
// Body: multipart/form-data  → nombre?, descripcion?, orden?  + archivo "imagen"?
const editarPlato = async (req, res) => {
  const { platoId } = req.params;
  const { nombre, descripcion, orden } = req.body;

  try {
    // Verificar que el plato pertenece a una tienda del usuario
    const { rows: check } = await pool.query(
      `SELECT p.*, mc.id AS menu_id FROM menu_casino_platos p
       JOIN menu_casino mc ON mc.id = p.menu_id
       JOIN tiendas t ON t.id = mc.tienda_id
       WHERE p.id = $1 AND t.duenio_id = $2`,
      [platoId, req.usuario.id]
    );
    if (!check.length) {
      if (req.file) _borrarImagen(`/uploads/${req.file.filename}`);
      return res.status(403).json({ error: 'No tienes permiso para este plato' });
    }

    const plato = check[0];
    let imagenUrl = plato.imagen_url;

    if (req.file) {
      // Borrar imagen anterior del disco
      _borrarImagen(plato.imagen_url);
      imagenUrl = `${process.env.BASE_URL || 'http://localhost:3000'}/uploads/${req.file.filename}`;
    }

    const { rows } = await pool.query(
      `UPDATE menu_casino_platos SET
         nombre      = COALESCE($1, nombre),
         descripcion = COALESCE($2, descripcion),
         imagen_url  = $3,
         orden       = COALESCE($4, orden)
       WHERE id = $5 RETURNING *`,
      [nombre?.trim() || null, descripcion?.trim() || null, imagenUrl, orden ?? null, platoId]
    );
    res.json(rows[0]);
  } catch (error) {
    if (req.file) _borrarImagen(`/uploads/${req.file.filename}`);
    console.error('Error editando plato:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// DELETE /api/menu-casino/platos/:platoId
const eliminarPlato = async (req, res) => {
  const { platoId } = req.params;
  try {
    const { rows: check } = await pool.query(
      `SELECT p.imagen_url FROM menu_casino_platos p
       JOIN menu_casino mc ON mc.id = p.menu_id
       JOIN tiendas t ON t.id = mc.tienda_id
       WHERE p.id = $1 AND t.duenio_id = $2`,
      [platoId, req.usuario.id]
    );
    if (!check.length) {
      return res.status(403).json({ error: 'No tienes permiso para este plato' });
    }
    _borrarImagen(check[0].imagen_url);
    await pool.query('DELETE FROM menu_casino_platos WHERE id = $1', [platoId]);
    res.json({ mensaje: 'Plato eliminado correctamente' });
  } catch (error) {
    console.error('Error eliminando plato:', error.message);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarMenuCasinoHoy,
  listarMenusCasino,
  crearMenuCasino,
  editarMenuCasino,
  eliminarMenuCasino,
  agregarPlato,
  editarPlato,
  eliminarPlato,
};