ALTER TABLE users
  ADD COLUMN order_block_source VARCHAR(64) NULL AFTER phone_verified_at,
  ADD COLUMN order_block_reason VARCHAR(255) NULL AFTER order_block_source,
  ADD COLUMN order_blocked_at DATETIME(3) NULL AFTER order_block_reason,
  ADD COLUMN order_blocked_until DATETIME(3) NULL AFTER order_blocked_at,
  ADD COLUMN risk_last_reviewed_at DATETIME(3) NULL AFTER order_blocked_until;

CREATE TABLE IF NOT EXISTS risk_events (
  id CHAR(36) NOT NULL PRIMARY KEY,
  user_id CHAR(36) NOT NULL,
  order_id CHAR(36) NULL,
  event_type VARCHAR(64) NOT NULL,
  status VARCHAR(64) NOT NULL,
  payload_json LONGTEXT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_risk_events_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_risk_events_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE SET NULL
);

CREATE INDEX idx_risk_events_user_id ON risk_events(user_id);
CREATE INDEX idx_risk_events_order_id ON risk_events(order_id);
CREATE INDEX idx_risk_events_type ON risk_events(event_type);
