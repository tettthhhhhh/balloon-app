const { query } = require('../db/pool');
const { verifyToken } = require('../lib/security');
const { httpError } = require('../lib/http-error');

async function attachCurrentUser(req, _res, next) {
  try {
    const auth = req.headers.authorization || '';
    if (!auth.startsWith('Bearer ')) {
      req.currentUser = null;
      return next();
    }

    const token = auth.slice('Bearer '.length);
    const payload = verifyToken(token);
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
        WHERE id = ?
        LIMIT 1
      `,
      [payload.sub],
    );

    req.currentUser = rows[0] || null;
    next();
  } catch (error) {
    next(error);
  }
}

function ensureAuthenticated(req, _res, next) {
  if (!req.currentUser) {
    return next(httpError(401, 'Нужна авторизация.'));
  }
  next();
}

function ensureRole(...roles) {
  return (req, _res, next) => {
    if (!req.currentUser) {
      return next(httpError(401, 'Нужна авторизация.'));
    }
    if (!roles.includes(req.currentUser.role)) {
      return next(httpError(403, 'Недостаточно прав.'));
    }
    next();
  };
}

module.exports = {
  attachCurrentUser,
  ensureAuthenticated,
  ensureRole,
};
