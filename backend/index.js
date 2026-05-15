const express  = require('express');
const cors     = require('cors');
const passport = require('passport');
const path = require('path');
require('dotenv').config();

const app  = express();
const PORT = process.env.PORT || 3000;

// Middlewares
app.use(cors());
app.use(express.json());

// Base de datos y Passport
require('./config/db');
require('./config/passport');
app.use(passport.initialize());

// Rutas
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api', require('./routes/productosRoutes'));
app.use('/api', require('./routes/alumnoRoutes')); 
app.use('/api', require('./routes/publicacionesRoutes'));
app.use('/api', require('./routes/menuCasinoRoutes'));

// Servir imágenes estáticas
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
// Ruta de upload
app.use('/api', require('./routes/uploadRoutes'));

// Ruta de prueba
app.get('/', (req, res) => {
  res.json({ mensaje: 'BiteBytes API funcionando correctamente' });
});

// Iniciar servidor
app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});