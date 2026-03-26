const { query, execute } = require('../db/pool');
const { httpError } = require('../lib/http-error');
const { serializeProduct } = require('../lib/serializers');

async function listProducts(currentUser) {
  const visibilityClause =
    currentUser?.role === 'admin' ? '' : 'WHERE is_visible = 1';
  const rows = await query(
    `
      SELECT
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
      FROM products
      ${visibilityClause}
      ORDER BY featured DESC, title ASC
    `,
  );

  return rows.map(serializeProduct);
}

async function updateProduct(productId, payload) {
  const rows = await query(
    `
      SELECT
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
      FROM products
      WHERE id = ?
      LIMIT 1
    `,
    [productId],
  );

  const current = rows[0];
  if (!current) {
    throw httpError(404, 'Товар не найден.');
  }

  const nextProduct = {
    title:
      typeof payload.title === 'string' && payload.title.trim()
        ? payload.title.trim()
        : current.title,
    subtitle:
      typeof payload.subtitle === 'string'
        ? payload.subtitle.trim()
        : current.subtitle,
    category:
      typeof payload.category === 'string' && payload.category.trim()
        ? payload.category.trim()
        : current.category,
    price:
      Number.isInteger(payload.price) && payload.price >= 0
        ? payload.price
        : Number(current.price),
    stock:
      Number.isInteger(payload.stock) && payload.stock >= 0
        ? payload.stock
        : Number(current.stock),
    unitLabel:
      typeof payload.unitLabel === 'string' && payload.unitLabel.trim()
        ? payload.unitLabel.trim()
        : current.unit_label,
    requiresReturn:
      typeof payload.requiresReturn === 'boolean'
        ? payload.requiresReturn
        : Boolean(current.requires_return),
    featured:
      typeof payload.featured === 'boolean'
        ? payload.featured
        : Boolean(current.featured),
    isVisible:
      typeof payload.isVisible === 'boolean'
        ? payload.isVisible
        : Boolean(current.is_visible),
    tint:
      typeof payload.tint === 'string' && payload.tint.trim()
        ? payload.tint.trim()
        : current.tint,
    previewImageUrl:
      typeof payload.previewImageUrl === 'string'
        ? payload.previewImageUrl.trim() || null
        : current.preview_image_url || null,
  };

  await execute(
    `
      UPDATE products
      SET
        title = ?,
        subtitle = ?,
        category = ?,
        price = ?,
        stock = ?,
        unit_label = ?,
        requires_return = ?,
        featured = ?,
        is_visible = ?,
        tint = ?,
        preview_image_url = ?
      WHERE id = ?
    `,
    [
      nextProduct.title,
      nextProduct.subtitle,
      nextProduct.category,
      nextProduct.price,
      nextProduct.stock,
      nextProduct.unitLabel,
      nextProduct.requiresReturn ? 1 : 0,
      nextProduct.featured ? 1 : 0,
      nextProduct.isVisible ? 1 : 0,
      nextProduct.tint,
      nextProduct.previewImageUrl,
      productId,
    ],
  );

  return serializeProduct({
    id: productId,
    title: nextProduct.title,
    subtitle: nextProduct.subtitle,
    category: nextProduct.category,
    price: nextProduct.price,
    stock: nextProduct.stock,
    unit_label: nextProduct.unitLabel,
    requires_return: nextProduct.requiresReturn ? 1 : 0,
    featured: nextProduct.featured ? 1 : 0,
    is_visible: nextProduct.isVisible ? 1 : 0,
    tint: nextProduct.tint,
    preview_image_url: nextProduct.previewImageUrl,
  });
}

module.exports = {
  listProducts,
  updateProduct,
};
