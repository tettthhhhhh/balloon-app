const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const { query, withTransaction, closePool } = require('./pool');
const { runMigrations } = require('./migrate');
const { makeStubExternalId, sha256 } = require('../lib/security');

const legacyFile = path.join(__dirname, '..', '..', 'data', 'store.json');

function readLegacyStore() {
  if (!fs.existsSync(legacyFile)) {
    return null;
  }

  return JSON.parse(fs.readFileSync(legacyFile, 'utf8'));
}

function toDate(value) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

async function seedLegacyStore({ force = false } = {}) {
  const legacyStore = readLegacyStore();
  if (!legacyStore) {
    return { seeded: false, reason: 'legacy-store-missing' };
  }

  const rows = await query(`
    SELECT
      (SELECT COUNT(*) FROM users) AS usersCount,
      (SELECT COUNT(*) FROM products) AS productsCount,
      (SELECT COUNT(*) FROM orders) AS ordersCount
  `);
  const counts = rows[0];
  const hasExistingData =
    counts.usersCount > 0 || counts.productsCount > 0 || counts.ordersCount > 0;

  if (hasExistingData && !force) {
    return { seeded: false, reason: 'database-not-empty' };
  }

  await withTransaction(async (connection) => {
    if (force) {
      await connection.query('SET FOREIGN_KEY_CHECKS = 0');
      await connection.query('TRUNCATE TABLE risk_events');
      await connection.query('TRUNCATE TABLE payment_events');
      await connection.query('TRUNCATE TABLE contract_events');
      await connection.query('TRUNCATE TABLE auth_verifications');
      await connection.query('TRUNCATE TABLE cylinder_logs');
      await connection.query('TRUNCATE TABLE contracts');
      await connection.query('TRUNCATE TABLE payments');
      await connection.query('TRUNCATE TABLE order_items');
      await connection.query('TRUNCATE TABLE orders');
      await connection.query('TRUNCATE TABLE products');
      await connection.query('TRUNCATE TABLE users');
      await connection.query('TRUNCATE TABLE app_config');
      await connection.query('SET FOREIGN_KEY_CHECKS = 1');
    }

    const config = legacyStore.config || {};
    await connection.execute(
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
        String(config.promoVideoId || 'OjxoHgnaNL8'),
        String(config.safetyVideoId || 'OjxoHgnaNL8'),
        String(config.supportPhone || '+7 (999) 555-40-40'),
        String(
          config.brandMessage ||
            'Собираем заказы без хаоса и конфликтов.',
        ),
      ],
    );

    for (const user of legacyStore.users || []) {
      const createdAt = toDate(user.createdAt) || new Date();
      const normalizedLogin = String(user.login || '').trim().toLowerCase();
      await connection.execute(
        `
          INSERT INTO users (
            id,
            login,
            email,
            phone,
            password_hash,
            full_name,
            role,
            auth_provider,
            email_verified_at,
            phone_verified_at,
            order_block_source,
            order_block_reason,
            order_blocked_at,
            order_blocked_until,
            risk_last_reviewed_at,
            created_at,
            updated_at
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, 'login', ?, ?, NULL, NULL, NULL, NULL, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            email = VALUES(email),
            phone = VALUES(phone),
            password_hash = VALUES(password_hash),
            full_name = VALUES(full_name),
            role = VALUES(role),
            email_verified_at = VALUES(email_verified_at),
            phone_verified_at = VALUES(phone_verified_at),
            order_block_source = VALUES(order_block_source),
            order_block_reason = VALUES(order_block_reason),
            order_blocked_at = VALUES(order_blocked_at),
            order_blocked_until = VALUES(order_blocked_until),
            risk_last_reviewed_at = VALUES(risk_last_reviewed_at),
            created_at = VALUES(created_at),
            updated_at = VALUES(updated_at)
        `,
        [
          user.id,
          normalizedLogin,
          `${normalizedLogin || 'user'}@indgas.local`,
          String(user.phone || ''),
          String(user.passwordHash || ''),
          String(user.fullName || ''),
          String(user.role || 'client'),
          createdAt,
          createdAt,
          createdAt,
          createdAt,
          createdAt,
        ],
      );
    }

    for (const product of legacyStore.products || []) {
      await connection.execute(
        `
          INSERT INTO products (
            id,
            title,
            subtitle,
            category,
            price,
          stock,
          unit_label,
          requires_return,
          featured,
          is_visible,
          tint,
          preview_image_url
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            subtitle = VALUES(subtitle),
            category = VALUES(category),
            price = VALUES(price),
            stock = VALUES(stock),
            unit_label = VALUES(unit_label),
            requires_return = VALUES(requires_return),
            featured = VALUES(featured),
            is_visible = VALUES(is_visible),
            tint = VALUES(tint),
            preview_image_url = VALUES(preview_image_url)
        `,
        [
          product.id,
          String(product.title || ''),
          String(product.subtitle || ''),
          String(product.category || 'general'),
          Number(product.price || 0),
          Number(product.stock || 0),
          String(product.unitLabel || 'шт'),
          product.requiresReturn ? 1 : 0,
          product.featured ? 1 : 0,
          product.isVisible === false ? 0 : 1,
          String(product.tint || '#FFFFFF'),
          typeof product.previewImageUrl === 'string' &&
            product.previewImageUrl.trim()
            ? product.previewImageUrl.trim()
            : null,
        ],
      );
    }

    for (const order of legacyStore.orders || []) {
      const createdAt = toDate(order.createdAt) || new Date();
      const updatedAt = createdAt;
      await connection.execute(
        `
          INSERT INTO orders (
            id,
            order_code,
            user_id,
            customer_name,
            customer_phone,
            delivery_type,
            location,
            payment_method,
            payment_mask,
            status,
            total_amount,
            stub_flow,
            cylinder_serial,
            created_at,
            updated_at,
            issued_at,
            returned_at
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?)
        `,
        [
          order.id,
          String(
            order.orderCode ||
              `GX-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`,
          ),
          order.userId,
          String(order.customerName || ''),
          String(order.customerPhone || ''),
          order.deliveryType === 'delivery' ? 'delivery' : 'pickup',
          String(order.location || ''),
          String(order.paymentMethod || 'card_demo'),
          String(order.paymentMask || ''),
          String(order.status || 'paid'),
          Number(order.totalAmount || 0),
          order.cylinderSerial ? String(order.cylinderSerial) : null,
          createdAt,
          updatedAt,
          toDate(order.issuedAt),
          toDate(order.returnedAt),
        ],
      );

      let firstReturnableItemId = null;
      let returnableQuantity = 0;

      for (const item of order.items || []) {
        const itemId = crypto.randomUUID();
        await connection.execute(
          `
            INSERT INTO order_items (
              id,
              order_id,
              product_id,
              title_snapshot,
              quantity,
              unit_price,
              requires_return
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
          `,
          [
            itemId,
            order.id,
            item.productId,
            String(item.title || ''),
            Number(item.quantity || 0),
            Number(item.unitPrice || 0),
            item.requiresReturn ? 1 : 0,
          ],
        );

        if (item.requiresReturn && firstReturnableItemId == null) {
          firstReturnableItemId = itemId;
        }
        if (item.requiresReturn) {
          returnableQuantity += Number(item.quantity || 0);
        }
      }

      const contractId = crypto.randomUUID();
      const paymentId = crypto.randomUUID();
      const orderCode = String(order.orderCode || '');
      const orderSnapshot = JSON.stringify({
        orderId: order.id,
        orderCode,
        userId: order.userId,
        totalAmount: order.totalAmount,
        items: order.items || [],
      });
      const contractStatus = order.status === 'draft' ? 'draft' : 'signed';
      const paymentStatus = order.status === 'draft' ? 'pending' : 'paid';

      await connection.execute(
        `
          INSERT INTO contracts (
            id,
            order_id,
            user_id,
            provider,
            document_number,
            document_title,
            document_body,
            signature_method,
            status,
            external_id,
            file_url,
            sign_hash,
            user_ip,
            device_info,
            stub_mode,
            created_at,
            signed_at,
            last_event_at,
            updated_at
          )
          VALUES (?, ?, ?, 'legacy-import', ?, ?, ?, 'legacy-import', ?, ?, ?, ?, NULL, 'legacy store import', 1, ?, ?, ?, ?)
        `,
        [
          contractId,
          order.id,
          order.userId,
          `LEGACY-${orderCode.toUpperCase()}`,
          `Legacy contract ${orderCode.toUpperCase()}`,
          `Legacy import contract for ${orderCode.toUpperCase()}`,
          contractStatus,
          makeStubExternalId('legacy_contract'),
          `/api/contracts/${contractId}/document`,
          sha256(orderSnapshot),
          createdAt,
          contractStatus === 'signed' ? createdAt : null,
          createdAt,
          createdAt,
        ],
      );

      await connection.execute(
        `
          INSERT INTO contract_events (
            id,
            contract_id,
            event_type,
            status,
            payload_json,
            created_at
          )
          VALUES (?, ?, 'legacy_import', ?, ?, ?)
        `,
        [
          crypto.randomUUID(),
          contractId,
          contractStatus,
          JSON.stringify({ source: 'legacy-store' }),
          createdAt,
        ],
      );

      await connection.execute(
        `
          INSERT INTO payments (
            id,
            order_id,
            provider,
            method,
            status,
            amount,
            currency,
            payment_mask,
            external_id,
            provider_reference,
            failure_reason,
            stub_mode,
            created_at,
            paid_at,
            last_event_at,
            updated_at
          )
          VALUES (?, ?, 'legacy-import', ?, ?, ?, 'RUB', ?, ?, ?, NULL, 1, ?, ?, ?, ?)
        `,
        [
          paymentId,
          order.id,
          String(order.paymentMethod || 'card_demo'),
          paymentStatus,
          Number(order.totalAmount || 0),
          String(order.paymentMask || ''),
          makeStubExternalId('legacy_payment'),
          makeStubExternalId('legacy_txn'),
          createdAt,
          paymentStatus === 'paid' ? createdAt : null,
          createdAt,
          createdAt,
        ],
      );

      await connection.execute(
        `
          INSERT INTO payment_events (
            id,
            payment_id,
            event_type,
            status,
            amount,
            provider_event_id,
            payload_json,
            created_at
          )
          VALUES (?, ?, 'legacy_import', ?, ?, ?, ?, ?)
        `,
        [
          crypto.randomUUID(),
          paymentId,
          paymentStatus,
          Number(order.totalAmount || 0),
          makeStubExternalId('legacy_event'),
          JSON.stringify({ source: 'legacy-store' }),
          createdAt,
        ],
      );

      if (order.cylinderSerial) {
        await connection.execute(
          `
            INSERT INTO cylinder_logs (
              id,
              order_id,
              order_item_id,
              qr_code,
              cylinder_serial_number,
              quantity,
              status,
              issued_at,
              returned_at,
              created_at,
              updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          `,
          [
            crypto.randomUUID(),
            order.id,
            firstReturnableItemId,
            String(order.orderCode || ''),
            String(order.cylinderSerial),
            Math.max(returnableQuantity, 1),
            order.status === 'completed' ? 'returned' : 'issued',
            toDate(order.issuedAt) || createdAt,
            toDate(order.returnedAt),
            createdAt,
            toDate(order.returnedAt) || toDate(order.issuedAt) || createdAt,
          ],
        );
      }
    }
  });

  return { seeded: true, reason: 'legacy-import-complete' };
}

if (require.main === module) {
  runMigrations()
    .then(() => seedLegacyStore({ force: process.argv.includes('--force') }))
    .then(async (result) => {
      console.log(`Legacy seed result: ${result.reason}`);
      await closePool();
    })
    .catch(async (error) => {
      console.error('Legacy seed failed.');
      console.error(error);
      await closePool();
      process.exitCode = 1;
    });
}

module.exports = {
  seedLegacyStore,
};
