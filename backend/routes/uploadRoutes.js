const express = require('express');
const router  = express.Router();
const path    = require('path');
const fs      = require('fs');
const { verificarToken } = require('../middleware/Authmiddleware');
const upload  = require('../middleware/upload');

// POST /api/upload
// Sube una imagen y devuelve la URL pública
router.post('/upload', verificarToken, upload.single('imagen'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No se recibió ninguna imagen' });
  }

  const baseUrl  = process.env.BASE_URL || 'http://localhost:3000';
  const imageUrl = `${baseUrl}/uploads/${req.file.filename}`;

  res.json({ url: imageUrl, filename: req.file.filename });
});

// DELETE /api/upload/:filename
// Elimina una imagen del servidor
router.delete('/upload/:filename', verificarToken, (req, res) => {
  const { filename } = req.params;

  // Seguridad: evitar path traversal
  if (filename.includes('..') || filename.includes('/')) {
    return res.status(400).json({ error: 'Nombre de archivo inválido' });
  }

  const filePath = path.join(__dirname, '..', 'uploads', filename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Archivo no encontrado' });
  }

  fs.unlinkSync(filePath);
  res.json({ mensaje: 'Imagen eliminada correctamente' });
});

module.exports = router;