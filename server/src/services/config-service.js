const { query, execute } = require('../db/pool');
const { serializeConfig } = require('../lib/serializers');

const fallbackConfig = {
  promoVideoId: 'OjxoHgnaNL8',
  safetyVideoId: 'OjxoHgnaNL8',
  supportPhone: '+7 (999) 555-40-40',
  brandMessage:
    'Быстрый заказ гелия, шаров и оборудования для праздников, фотозон и выездных оформлений.',
};

async function getConfig() {
  const rows = await query(
    `
      SELECT
        promo_video_id,
        safety_video_id,
        support_phone,
        brand_message
      FROM app_config
      WHERE id = 1
      LIMIT 1
    `,
  );

  if (rows.length === 0) {
    return fallbackConfig;
  }

  return serializeConfig(rows[0]);
}

async function updateConfig(payload) {
  const current = await getConfig();
  const nextConfig = {
    promoVideoId: String(payload.promoVideoId || current.promoVideoId),
    safetyVideoId: String(payload.safetyVideoId || current.safetyVideoId),
    supportPhone: String(payload.supportPhone || current.supportPhone),
    brandMessage: String(payload.brandMessage || current.brandMessage),
  };

  await execute(
    `
      INSERT INTO app_config (
        id,
        promo_video_id,
        safety_video_id,
        support_phone,
        brand_message
      )
      VALUES (1, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        promo_video_id = VALUES(promo_video_id),
        safety_video_id = VALUES(safety_video_id),
        support_phone = VALUES(support_phone),
        brand_message = VALUES(brand_message)
    `,
    [
      nextConfig.promoVideoId,
      nextConfig.safetyVideoId,
      nextConfig.supportPhone,
      nextConfig.brandMessage,
    ],
  );

  return getConfig();
}

module.exports = {
  getConfig,
  updateConfig,
};
