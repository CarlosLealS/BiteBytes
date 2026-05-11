const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

pool.connect()
  .then(() => console.log('Conectado a Supabase - bitebytes'))
  .catch(err => console.error('Error conectando a Supabase:', err.message));

module.exports = pool;
