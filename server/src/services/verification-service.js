const crypto = require('crypto');

const { query, withTransaction } = require('../db/pool');
const { httpError } = require('../lib/http-error');
const { sha256, makeStubExternalId } = require('../lib/security');
const {
  serializeUser,
  serializeVerification,
  serializeVerificationState,
} = require('../lib/serializers');
const { syncUserRiskState } = require('./risk-service');

const CODE_TTL_MINUTES = 10;
const MAX_ATTEMPTS = 5;

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizePhone(value) {
  return String(value || '').trim();
}

function createVerificationCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

function resolveVerificationPurpose(channel) {
  return channel === 'email' ? 'register_email' : 'register_phone';
}

function computeVerificationRequirements(user) {
  return {
    requiresEmail: Boolean(user.email) && !user.email_verified_at,
    requiresPhone: Boolean(user.phone) && !user.phone_verified_at,
  };
}

async function expireStaleVerifications(connection, userId) {
  await connection.execute(
    `
      UPDATE auth_verifications
      SET
        status = 'expired',
        updated_at = CURRENT_TIMESTAMP(3)
      WHERE user_id = ? AND status = 'pending' AND expires_at < CURRENT_TIMESTAMP(3)
    `,
    [userId],
  );
}

async function loadUserForUpdate(userId, connection) {
  const rows = await query(
    `
      SELECT
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
        created_at,
        updated_at
      FROM users
      WHERE id = ?
      LIMIT 1
      FOR UPDATE
    `,
    [userId],
    connection,
  );

  const user = rows[0];
  if (!user) {
    throw httpError(404, 'Пользователь не найден.');
  }
  return user;
}

async function findLatestPendingVerification(userId, channel, connection) {
  const rows = await query(
    `
      SELECT
        id,
        user_id,
        purpose,
        channel,
        provider,
        target_value,
        code_preview,
        status,
        external_id,
        attempt_count,
        max_attempts,
        stub_mode,
        expires_at,
        verified_at,
        created_at,
        updated_at
      FROM auth_verifications
      WHERE user_id = ? AND channel = ? AND status = 'pending'
      ORDER BY created_at DESC
      LIMIT 1
    `,
    [userId, channel],
    connection,
  );

  return rows[0] || null;
}

async function loadPendingVerifications(userId, connection) {
  return query(
    `
      SELECT
        id,
        user_id,
        purpose,
        channel,
        provider,
        target_value,
        code_preview,
        status,
        external_id,
        attempt_count,
        max_attempts,
        stub_mode,
        expires_at,
        verified_at,
        created_at,
        updated_at
      FROM auth_verifications
      WHERE user_id = ? AND status = 'pending'
      ORDER BY created_at ASC
    `,
    [userId],
    connection,
  );
}

async function createPendingVerification(connection, user, channel) {
  const targetValue =
    channel === 'email' ? normalizeEmail(user.email) : normalizePhone(user.phone);

  if (!targetValue) {
    return null;
  }

  await connection.execute(
    `
      UPDATE auth_verifications
      SET
        status = 'superseded',
        updated_at = CURRENT_TIMESTAMP(3)
      WHERE user_id = ? AND channel = ? AND status = 'pending'
    `,
    [user.id, channel],
  );

  const id = crypto.randomUUID();
  const code = createVerificationCode();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + CODE_TTL_MINUTES * 60 * 1000);

  await connection.execute(
    `
      INSERT INTO auth_verifications (
        id,
        user_id,
        purpose,
        channel,
        provider,
        target_value,
        code_hash,
        code_preview,
        status,
        external_id,
        attempt_count,
        max_attempts,
        stub_mode,
        expires_at,
        verified_at,
        consumed_at,
        created_at,
        updated_at
      )
      VALUES (?, ?, ?, ?, 'stub-channel', ?, ?, ?, 'pending', ?, 0, ?, 1, ?, NULL, NULL, ?, ?)
    `,
    [
      id,
      user.id,
      resolveVerificationPurpose(channel),
      channel,
      targetValue,
      sha256(`verify:${code}`),
      code,
      makeStubExternalId(`verify_${channel}`),
      MAX_ATTEMPTS,
      expiresAt,
      now,
      now,
    ],
  );

  return {
    id,
    user_id: user.id,
    purpose: resolveVerificationPurpose(channel),
    channel,
    provider: 'stub-channel',
    target_value: targetValue,
    code_preview: code,
    status: 'pending',
    external_id: null,
    attempt_count: 0,
    max_attempts: MAX_ATTEMPTS,
    stub_mode: 1,
    expires_at: expiresAt,
    verified_at: null,
    created_at: now,
    updated_at: now,
  };
}

async function ensurePendingVerificationForUser(connection, user) {
  const { requiresEmail, requiresPhone } = computeVerificationRequirements(user);

  if (requiresEmail) {
    const existing = await findLatestPendingVerification(user.id, 'email', connection);
    if (existing) {
      return existing;
    }
    return createPendingVerification(connection, user, 'email');
  }

  if (requiresPhone) {
    const existing = await findLatestPendingVerification(user.id, 'phone', connection);
    if (existing) {
      return existing;
    }
    return createPendingVerification(connection, user, 'phone');
  }

  return null;
}

async function buildVerificationResponseForUser(userId) {
  return withTransaction(async (connection) => {
    const user = await loadUserForUpdate(userId, connection);
    await expireStaleVerifications(connection, userId);
    await ensurePendingVerificationForUser(connection, user);
    const pendingRows = await loadPendingVerifications(userId, connection);
    const risk = await syncUserRiskState(user.id, connection);

    return {
      user: serializeUser(user, risk),
      verification: serializeVerificationState(
        user,
        pendingRows.map(serializeVerification),
      ),
    };
  });
}

async function resendVerification(currentUser, { channel } = {}) {
  return withTransaction(async (connection) => {
    const user = await loadUserForUpdate(currentUser.id, connection);
    const requirements = computeVerificationRequirements(user);
    const targetChannel =
      channel ||
      (requirements.requiresEmail
        ? 'email'
        : requirements.requiresPhone
          ? 'phone'
          : null);

    if (!targetChannel) {
      const pendingRows = await loadPendingVerifications(user.id, connection);
      const risk = await syncUserRiskState(user.id, connection);
      return {
        user: serializeUser(user, risk),
        verification: serializeVerificationState(
          user,
          pendingRows.map(serializeVerification),
        ),
      };
    }

    if (targetChannel === 'email' && !requirements.requiresEmail) {
      throw httpError(409, 'Email уже подтверждён.');
    }
    if (targetChannel === 'phone' && !requirements.requiresPhone) {
      throw httpError(409, 'Телефон уже подтверждён.');
    }

    await createPendingVerification(connection, user, targetChannel);
    const pendingRows = await loadPendingVerifications(user.id, connection);
    const risk = await syncUserRiskState(user.id, connection);

    return {
      user: serializeUser(user, risk),
      verification: serializeVerificationState(
        user,
        pendingRows.map(serializeVerification),
      ),
    };
  });
}

async function confirmVerification(currentUser, { verificationId, code }) {
  const normalizedId = String(verificationId || '').trim();
  const normalizedCode = String(code || '').trim();

  if (!normalizedId) {
    throw httpError(400, 'Не указан verification id.');
  }
  if (normalizedCode.length < 4) {
    throw httpError(400, 'Код подтверждения слишком короткий.');
  }

  return withTransaction(async (connection) => {
    const rows = await query(
      `
        SELECT
          v.id,
          v.user_id,
          v.purpose,
          v.channel,
          v.provider,
          v.target_value,
          v.code_hash,
          v.code_preview,
          v.status,
          v.external_id,
          v.attempt_count,
          v.max_attempts,
          v.stub_mode,
          v.expires_at,
          v.verified_at,
          v.created_at,
          v.updated_at,
          u.email,
          u.phone,
          u.email_verified_at,
          u.phone_verified_at
        FROM auth_verifications v
        INNER JOIN users u ON u.id = v.user_id
        WHERE v.id = ?
        LIMIT 1
        FOR UPDATE
      `,
      [normalizedId],
      connection,
    );

    const record = rows[0];
    if (!record) {
      throw httpError(404, 'Запрос на подтверждение не найден.');
    }
    if (currentUser.role !== 'admin' && currentUser.id !== record.user_id) {
      throw httpError(403, 'Недостаточно прав для подтверждения.');
    }

    if (record.status !== 'pending') {
      const user = await loadUserForUpdate(record.user_id, connection);
      await ensurePendingVerificationForUser(connection, user);
      const pendingRows = await loadPendingVerifications(record.user_id, connection);
      const risk = await syncUserRiskState(user.id, connection);
      return {
        user: serializeUser(user, risk),
        verification: serializeVerificationState(
          user,
          pendingRows.map(serializeVerification),
        ),
      };
    }

    if (new Date(record.expires_at).getTime() < Date.now()) {
      await connection.execute(
        `
          UPDATE auth_verifications
          SET
            status = 'expired',
            updated_at = CURRENT_TIMESTAMP(3)
          WHERE id = ?
        `,
        [record.id],
      );
      throw httpError(410, 'Код подтверждения истёк. Запросите новый.');
    }

    const isCodeValid =
      sha256(`verify:${normalizedCode}`) === String(record.code_hash || '');

    if (!isCodeValid) {
      const nextAttempts = Number(record.attempt_count || 0) + 1;
      const nextStatus = nextAttempts >= Number(record.max_attempts || MAX_ATTEMPTS)
        ? 'expired'
        : 'pending';

      await connection.execute(
        `
          UPDATE auth_verifications
          SET
            attempt_count = ?,
            status = ?,
            updated_at = CURRENT_TIMESTAMP(3)
          WHERE id = ?
        `,
        [nextAttempts, nextStatus, record.id],
      );

      throw httpError(
        400,
        nextStatus === 'expired'
          ? 'Лимит попыток исчерпан. Запросите новый код.'
          : 'Неверный код подтверждения.',
      );
    }

    await connection.execute(
      `
        UPDATE auth_verifications
        SET
          status = 'verified',
          attempt_count = ?,
          verified_at = CURRENT_TIMESTAMP(3),
          consumed_at = CURRENT_TIMESTAMP(3),
          updated_at = CURRENT_TIMESTAMP(3)
        WHERE id = ?
      `,
      [Number(record.attempt_count || 0) + 1, record.id],
    );

    if (record.channel === 'email') {
      await connection.execute(
        `
          UPDATE users
          SET
            email_verified_at = CURRENT_TIMESTAMP(3),
            auth_provider = 'email',
            updated_at = CURRENT_TIMESTAMP(3)
          WHERE id = ?
        `,
        [record.user_id],
      );
    } else {
      await connection.execute(
        `
          UPDATE users
          SET
            phone_verified_at = CURRENT_TIMESTAMP(3),
            auth_provider = 'phone_stub',
            updated_at = CURRENT_TIMESTAMP(3)
          WHERE id = ?
        `,
        [record.user_id],
      );
    }

    const user = await loadUserForUpdate(record.user_id, connection);
    await ensurePendingVerificationForUser(connection, user);
    const pendingRows = await loadPendingVerifications(record.user_id, connection);
    const risk = await syncUserRiskState(user.id, connection);

    return {
      user: serializeUser(user, risk),
      verification: serializeVerificationState(
        user,
        pendingRows.map(serializeVerification),
      ),
    };
  });
}

module.exports = {
  normalizeEmail,
  normalizePhone,
  buildVerificationResponseForUser,
  resendVerification,
  confirmVerification,
  ensurePendingVerificationForUser,
  createPendingVerification,
};
