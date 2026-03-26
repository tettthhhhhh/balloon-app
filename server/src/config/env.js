const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '..', '.env') });

function toNumber(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseOrigins(value) {
  const raw = String(value || '*').trim();
  if (!raw || raw === '*') {
    return '*';
  }

  return raw
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

module.exports = {
  PORT: toNumber(process.env.PORT, 8787),
  APP_SECRET: String(process.env.APP_SECRET || 'gas-express-dev-secret'),
  CORS_ORIGINS: parseOrigins(process.env.CORS_ORIGIN),
  DB_HOST: String(process.env.DB_HOST || '127.0.0.1'),
  DB_PORT: toNumber(process.env.DB_PORT, 3306),
  DB_NAME: String(process.env.DB_NAME || 'indgas_dev'),
  DB_USER: String(process.env.DB_USER || 'indgas'),
  DB_PASSWORD: String(process.env.DB_PASSWORD || ''),
};
