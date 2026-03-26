const crypto = require('crypto');

const { query, execute } = require('../db/pool');
const { httpError } = require('../lib/http-error');
const { hashPassword, verifyPassword, signToken } = require('../lib/security');
const {
  normalizeEmail,
  normalizePhone,
  buildVerificationResponseForUser,
} = require('./verification-service');

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

async function register({ login, password, fullName, phone, email }) {
  const normalizedLogin = String(login || '').trim().toLowerCase();
  const normalizedPassword = String(password || '');
  const normalizedName = String(fullName || '').trim();
  const normalizedPhone = normalizePhone(phone);
  const normalizedEmail = normalizeEmail(email);

  if (normalizedLogin.length < 3) {
    throw httpError(400, 'Логин должен быть не короче 3 символов.');
  }
  if (normalizedPassword.length < 6) {
    throw httpError(400, 'Пароль должен быть не короче 6 символов.');
  }
  if (normalizedName.length < 3) {
    throw httpError(400, 'Укажите имя пользователя.');
  }
  if (!isValidEmail(normalizedEmail)) {
    throw httpError(400, 'Укажите корректный email.');
  }
  if (normalizedPhone.length < 6) {
    throw httpError(400, 'Укажите телефон для подтверждения.');
  }

  const existing = await query(
    'SELECT id, login, email FROM users WHERE login = ? OR email = ? LIMIT 1',
    [normalizedLogin, normalizedEmail],
  );
  if (existing.length > 0) {
    const duplicate = existing[0];
    throw httpError(
      409,
      duplicate.login === normalizedLogin
        ? 'Такой логин уже занят.'
        : 'Такой email уже используется.',
    );
  }

  const user = {
    id: crypto.randomUUID(),
    login: normalizedLogin,
    email: normalizedEmail,
    phone: normalizedPhone,
    passwordHash: hashPassword(normalizedPassword),
    fullName: normalizedName,
    role: 'client',
    createdAt: new Date(),
  };

  await execute(
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
        created_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, 'email', NULL, NULL, ?)
    `,
    [
      user.id,
      user.login,
      user.email,
      user.phone,
      user.passwordHash,
      user.fullName,
      user.role,
      user.createdAt,
    ],
  );

  const verificationState = await buildVerificationResponseForUser(user.id);

  return {
    token: signToken({ id: user.id, role: user.role }),
    user: verificationState.user,
    verification: verificationState.verification,
  };
}

async function signIn({ login, password }) {
  const normalizedLogin = String(login || '').trim().toLowerCase();
  const normalizedPassword = String(password || '');
  const lookupField = normalizedLogin.includes('@') ? 'email' : 'login';
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
        email_verified_at,
        phone_verified_at,
        created_at
      FROM users
      WHERE ${lookupField} = ?
      LIMIT 1
    `,
    [normalizedLogin],
  );

  const user = rows[0];
  if (!user || !verifyPassword(normalizedPassword, user.password_hash)) {
    throw httpError(401, 'Неверный логин или пароль.');
  }

  const verificationResponse = await buildVerificationResponseForUser(user.id);

  return {
    token: signToken({ id: user.id, role: user.role }),
    user: verificationResponse.user,
    verification: verificationResponse.verification,
  };
}

module.exports = {
  register,
  signIn,
};
