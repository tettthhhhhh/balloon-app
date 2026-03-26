CREATE TABLE IF NOT EXISTS schema_migrations (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  applied_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS app_config (
  id TINYINT NOT NULL PRIMARY KEY,
  promo_video_id VARCHAR(64) NOT NULL,
  safety_video_id VARCHAR(64) NOT NULL,
  support_phone VARCHAR(64) NOT NULL,
  brand_message TEXT NOT NULL,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) NOT NULL PRIMARY KEY,
  login VARCHAR(64) NOT NULL UNIQUE,
  email VARCHAR(190) NULL UNIQUE,
  phone VARCHAR(64) NOT NULL DEFAULT '',
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(190) NOT NULL,
  role ENUM('client', 'courier', 'admin') NOT NULL DEFAULT 'client',
  auth_provider ENUM('login', 'email', 'phone_stub') NOT NULL DEFAULT 'login',
  email_verified_at DATETIME(3) NULL,
  phone_verified_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(64) NOT NULL PRIMARY KEY,
  title VARCHAR(190) NOT NULL,
  subtitle TEXT NOT NULL,
  category VARCHAR(64) NOT NULL,
  price INT NOT NULL,
  stock INT NOT NULL DEFAULT 0,
  unit_label VARCHAR(32) NOT NULL DEFAULT 'шт',
  requires_return TINYINT(1) NOT NULL DEFAULT 0,
  featured TINYINT(1) NOT NULL DEFAULT 0,
  tint VARCHAR(32) NOT NULL DEFAULT '#FFFFFF',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS orders (
  id CHAR(36) NOT NULL PRIMARY KEY,
  order_code VARCHAR(32) NOT NULL UNIQUE,
  user_id CHAR(36) NOT NULL,
  customer_name VARCHAR(190) NOT NULL,
  customer_phone VARCHAR(64) NOT NULL DEFAULT '',
  delivery_type ENUM('pickup', 'delivery') NOT NULL DEFAULT 'pickup',
  location VARCHAR(255) NOT NULL,
  payment_method VARCHAR(64) NOT NULL DEFAULT 'card_demo',
  payment_mask VARCHAR(64) NOT NULL DEFAULT '',
  status ENUM(
    'draft',
    'awaiting_signature',
    'awaiting_payment',
    'paid',
    'active',
    'completed',
    'blocked'
  ) NOT NULL DEFAULT 'draft',
  total_amount INT NOT NULL DEFAULT 0,
  stub_flow TINYINT(1) NOT NULL DEFAULT 1,
  cylinder_serial VARCHAR(128) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  issued_at DATETIME(3) NULL,
  returned_at DATETIME(3) NULL,
  CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);

CREATE TABLE IF NOT EXISTS order_items (
  id CHAR(36) NOT NULL PRIMARY KEY,
  order_id CHAR(36) NOT NULL,
  product_id VARCHAR(64) NOT NULL,
  title_snapshot VARCHAR(190) NOT NULL,
  quantity INT NOT NULL,
  unit_price INT NOT NULL,
  requires_return TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE RESTRICT
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);

CREATE TABLE IF NOT EXISTS cylinder_logs (
  id CHAR(36) NOT NULL PRIMARY KEY,
  order_id CHAR(36) NOT NULL,
  order_item_id CHAR(36) NULL,
  qr_code VARCHAR(64) NULL,
  cylinder_serial_number VARCHAR(128) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  status ENUM('reserved', 'issued', 'returned') NOT NULL DEFAULT 'reserved',
  issued_at DATETIME(3) NULL,
  returned_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_cylinder_logs_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_cylinder_logs_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id)
    ON DELETE SET NULL
);

CREATE INDEX idx_cylinder_logs_order_id ON cylinder_logs(order_id);
CREATE INDEX idx_cylinder_logs_serial ON cylinder_logs(cylinder_serial_number);

CREATE TABLE IF NOT EXISTS contracts (
  id CHAR(36) NOT NULL PRIMARY KEY,
  order_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  provider VARCHAR(64) NOT NULL DEFAULT 'stub-sign',
  status ENUM('draft', 'pending_signature', 'signed', 'rejected') NOT NULL DEFAULT 'draft',
  external_id VARCHAR(128) NULL,
  file_url VARCHAR(255) NULL,
  sign_hash VARCHAR(128) NULL,
  user_ip VARCHAR(64) NULL,
  device_info VARCHAR(255) NULL,
  stub_mode TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  signed_at DATETIME(3) NULL,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_contracts_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_contracts_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

CREATE INDEX idx_contracts_order_id ON contracts(order_id);

CREATE TABLE IF NOT EXISTS payments (
  id CHAR(36) NOT NULL PRIMARY KEY,
  order_id CHAR(36) NOT NULL,
  provider VARCHAR(64) NOT NULL DEFAULT 'stub-pay',
  method VARCHAR(64) NOT NULL DEFAULT 'card_demo',
  status ENUM('pending', 'paid', 'failed', 'refunded') NOT NULL DEFAULT 'pending',
  amount INT NOT NULL DEFAULT 0,
  payment_mask VARCHAR(64) NULL,
  external_id VARCHAR(128) NULL,
  stub_mode TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  paid_at DATETIME(3) NULL,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE
);

CREATE INDEX idx_payments_order_id ON payments(order_id);
