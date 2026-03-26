const { runMigrations } = require('./migrate');
const { seedLegacyStore } = require('./seed-legacy');

async function bootstrapDatabase() {
  await runMigrations();
  await seedLegacyStore();
}

module.exports = {
  bootstrapDatabase,
};
