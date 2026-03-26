const { runMigrations } = require('./migrate');
const { seedLegacyStore } = require('./seed-legacy');
const { closePool } = require('./pool');

async function resetDatabase() {
  await runMigrations();
  await seedLegacyStore({ force: true });
}

if (require.main === module) {
  resetDatabase()
    .then(async () => {
      console.log('Database reset complete.');
      await closePool();
    })
    .catch(async (error) => {
      console.error('Database reset failed.');
      console.error(error);
      await closePool();
      process.exitCode = 1;
    });
}

module.exports = {
  resetDatabase,
};
