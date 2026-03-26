const fs = require('fs');
const path = require('path');

const { pool, query } = require('./pool');

const migrationsDir = path.join(__dirname, 'migrations');

async function ensureMigrationsTable() {
  await query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255) NOT NULL UNIQUE,
      applied_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    )
  `);
}

async function runMigrations() {
  await ensureMigrationsTable();

  const files = fs
    .readdirSync(migrationsDir)
    .filter((name) => name.endsWith('.sql'))
    .sort((left, right) => left.localeCompare(right));

  for (const name of files) {
    const rows = await query(
      'SELECT name FROM schema_migrations WHERE name = ? LIMIT 1',
      [name],
    );

    if (rows.length > 0) {
      continue;
    }

    const sql = fs.readFileSync(path.join(migrationsDir, name), 'utf8');
    const connection = await pool.getConnection();
    try {
      await connection.query(sql);
      await connection.execute(
        'INSERT INTO schema_migrations (name) VALUES (?)',
        [name],
      );
    } finally {
      connection.release();
    }
  }
}

if (require.main === module) {
  runMigrations()
    .then(async () => {
      console.log('MySQL migrations completed.');
      await pool.end();
    })
    .catch(async (error) => {
      console.error('MySQL migrations failed.');
      console.error(error);
      await pool.end();
      process.exitCode = 1;
    });
}

module.exports = {
  runMigrations,
};
