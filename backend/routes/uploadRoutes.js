const express    = require('express');
const router     = express.Router();
const multer     = require('multer');
const cloudinary = require('../config/cloudinary');
const { verificarToken } = require('../middleware/Authmiddleware');

// Guardar en memoria, no en disco
const upload = multer({ storage: multer.memoryStorage() });

router.delete('/upload', verificarToken, async (req, res) => {
  try {
    const { public_id } = req.body;
    if (!public_id) return res.status(400).json({ error: 'public_id requerido' });

    await cloudinary.uploader.destroy(public_id);
    res.json({ mensaje: 'Imagen eliminada' });
  } catch (e) {
    console.error('Delete error:', e);
    res.status(500).json({ error: 'Error al eliminar imagen' });
  }
});

router.post('/upload', verificarToken, upload.single('imagen'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No se recibió imagen' });

    // Subir buffer directo a Cloudinary
    const resultado = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder:   'bitebytes',
          transformation: [{ width: 800, quality: 'auto', fetch_format: 'auto' }],
        },
        (error, result) => {
          if (error) reject(error);
          else resolve(result);
        }
      );
      stream.end(req.file.buffer);
    });

    res.json({ url: resultado.secure_url, public_id: resultado.public_id });
  } catch (e) {
    console.error('Upload error:', e);
    res.status(500).json({ error: 'Error al subir imagen' });
  }
});

module.exports = router;