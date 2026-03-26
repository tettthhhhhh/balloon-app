const mysql = require('mysql2/promise');

const {
  DB_HOST,
  DB_PORT,
  DB_NAME,
  DB_USER,
  DB_PASSWORD,
} = require('../config/env');

const pool = mysql.createPool({
  host: DB_HOST,
  port: DB_PORT,
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASSWORD,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  multipleStatements: true,
  timezone: 'Z',
});

async function query(sql, params = [], executor = pool) {
  const [rows] = await executor.query(sql, params);
  return rows;
}

async function execute(sql, params = [], executor = pool) {
  const [result] = await executor.execute(sql, params);
  return result;
}

async function withTransaction(callback) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const result = await callback(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

async function closePool() {
  await pool.end();
}

module.exports = {
  pool,
  query,
  execute,
  withTransaction,
  closePool,
};
