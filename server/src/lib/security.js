const crypto = require('crypto');

const { APP_SECRET } = require('../config/env');
const { httpError } = require('./http-error');

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto
    .pbkdf2Sync(password, salt, 120000, 32, 'sha256')
    .toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, storedHash) {
  const [salt, expectedHash] = String(storedHash).split(':');
  if (!salt || !expectedHash) {
    return false;
  }

  const actualHash = crypto
    .pbkdf2Sync(password, salt, 120000, 32, 'sha256')
    .toString('hex');

  return crypto.timingSafeEqual(
    Buffer.from(actualHash, 'utf8'),
    Buffer.from(expectedHash, 'utf8'),
  );
}

function signToken(user) {
  const header = Buffer.from(
    JSON.stringify({ alg: 'HS256', typ: 'JWT' }),
    'utf8',
  ).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({
      sub: user.id,
      role: user.role,
      exp: Date.now() + 7 * 24 * 60 * 60 * 1000,
    }),
    'utf8',
  ).toString('base64url');

  const signature = crypto
    .createHmac('sha256', APP_SECRET)
    .update(`${header}.${payload}`)
    .digest('base64url');

  return `${header}.${payload}.${signature}`;
}

function verifyToken(token) {
  const [header, payload, signature] = String(token).split('.');
  if (!header || !payload || !signature) {
    throw httpError(401, 'Некорректный токен.');
  }

  const expected = crypto
    .createHmac('sha256', APP_SECRET)
    .update(`${header}.${payload}`)
    .digest('base64url');

  if (
    !crypto.timingSafeEqual(
      Buffer.from(signature, 'utf8'),
      Buffer.from(expected, 'utf8'),
    )
  ) {
    throw httpError(401, 'Подпись токена не совпадает.');
  }

  const parsed = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  if (parsed.exp < Date.now()) {
    throw httpError(401, 'Сессия истекла.');
  }
  return parsed;
}

function signAccessToken(payload, expiresAt) {
  const body = Buffer.from(
    JSON.stringify({
      ...payload,
      exp: expiresAt instanceof Date ? expiresAt.getTime() : Number(expiresAt),
    }),
    'utf8',
  ).toString('base64url');

  const signature = crypto
    .createHmac('sha256', APP_SECRET)
    .update(`ACCESS.${body}`)
    .digest('base64url');

  return `${body}.${signature}`;
}

function verifyAccessToken(token, expectedScope = null) {
  const [body, signature] = String(token).split('.');
  if (!body || !signature) {
    throw httpError(401, 'Некорректная ссылка доступа к документу.');
  }

  const expected = crypto
    .createHmac('sha256', APP_SECRET)
    .update(`ACCESS.${body}`)
    .digest('base64url');

  if (
    !crypto.timingSafeEqual(
      Buffer.from(signature, 'utf8'),
      Buffer.from(expected, 'utf8'),
    )
  ) {
    throw httpError(401, 'Подпись ссылки доступа не совпадает.');
  }

  let parsed;
  try {
    parsed = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    throw httpError(401, 'Ссылка доступа повреждена.');
  }

  if (!parsed || typeof parsed !== 'object') {
    throw httpError(401, 'Ссылка доступа повреждена.');
  }
  if (Number(parsed.exp || 0) < Date.now()) {
    throw httpError(401, 'Срок действия ссылки на документ истёк.');
  }
  if (expectedScope && parsed.scope !== expectedScope) {
    throw httpError(403, 'Ссылка доступа выдана не для этого документа.');
  }

  return parsed;
}

function makeStubExternalId(prefix) {
  return `${prefix}_${crypto.randomUUID().slice(0, 8)}`;
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

module.exports = {
  hashPassword,
  verifyPassword,
  signToken,
  verifyToken,
  signAccessToken,
  verifyAccessToken,
  makeStubExternalId,
  sha256,
  escapeHtml,
};
