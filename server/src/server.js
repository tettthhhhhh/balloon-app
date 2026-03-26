const { PORT } = require('./config/env');
const { bootstrapDatabase } = require('./db/bootstrap');
const { createApp } = require('./app');
const { closePool } = require('./db/pool');

async function startServer() {
  await bootstrapDatabase();

  const app = createApp();
  const server = app.listen(PORT, () => {
    console.log(`IndGas Express API is running on http://localhost:${PORT}/api`);
  });

  const shutdown = async () => {
    server.close(async () => {
      await closePool();
      process.exit(0);
    });
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

startServer().catch(async (error) => {
  console.error('Failed to start IndGas Express API.');
  console.error(error);
  await closePool();
  process.exitCode = 1;
});
