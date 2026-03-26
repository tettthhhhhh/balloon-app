ALTER TABLE products
  ADD COLUMN is_visible TINYINT(1) NOT NULL DEFAULT 1 AFTER featured,
  ADD COLUMN preview_image_url VARCHAR(255) NULL AFTER tint;

UPDATE products
SET is_visible = 1
WHERE is_visible IS NULL;
