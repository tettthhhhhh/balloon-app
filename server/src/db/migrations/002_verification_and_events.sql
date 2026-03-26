ALTER TABLE users
  ADD COLUMN updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3);

ALTER TABLE contracts
  ADD COLUMN document_number VARCHAR(64) NULL AFTER provider,
  ADD COLUMN document_title VARCHAR(190) NULL AFTER document_number,
  ADD COLUMN document_body LONGTEXT NULL AFTER document_title,
  ADD COLUMN signature_method VARCHAR(64) NOT NULL DEFAULT 'stub-simple-sign' AFTER document_body,
  ADD COLUMN last_event_at DATETIME(3) NULL AFTER signed_at;

ALTER TABLE payments
  ADD COLUMN currency VARCHAR(8) NOT NULL DEFAULT 'RUB' AFTER amount,
  ADD COLUMN provider_reference VARCHAR(128) NULL AFTER external_id,
  ADD COLUMN failure_reason VARCHAR(255) NULL AFTER provider_reference,
  ADD COLUMN last_event_at DATETIME(3) NULL AFTER paid_at;

CREATE TABLE IF NOT EXISTS auth_verifications (
  id CHAR(36) NOT NULL PRIMARY KEY,
  user_id CHAR(36) NOT NULL,
  purpose VARCHAR(64) NOT NULL,
  channel ENUM('email', 'phone') NOT NULL,
  provider VARCHAR(64) NOT NULL DEFAULT 'stub-channel',
  target_value VARCHAR(190) NOT NULL,
  code_hash VARCHAR(128) NOT NULL,
  code_preview VARCHAR(16) NOT NULL DEFAULT '',
  status ENUM('pending', 'verified', 'expired', 'superseded') NOT NULL DEFAULT 'pending',
  external_id VARCHAR(128) NULL,
  attempt_count INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 5,
  stub_mode TINYINT(1) NOT NULL DEFAULT 1,
  expires_at DATETIME(3) NOT NULL,
  verified_at DATETIME(3) NULL,
  consumed_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_auth_verifications_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

CREATE INDEX idx_auth_verifications_user_id ON auth_verifications(user_id);
CREATE INDEX idx_auth_verifications_status ON auth_verifications(status);
CREATE INDEX idx_auth_verifications_channel ON auth_verifications(channel);

CREATE TABLE IF NOT EXISTS contract_events (
  id CHAR(36) NOT NULL PRIMARY KEY,
  contract_id CHAR(36) NOT NULL,
  event_type VARCHAR(64) NOT NULL,
  status VARCHAR(64) NOT NULL,
  payload_json LONGTEXT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_contract_events_contract
    FOREIGN KEY (contract_id) REFERENCES contracts(id)
    ON DELETE CASCADE
);

CREATE INDEX idx_contract_events_contract_id ON contract_events(contract_id);

CREATE TABLE IF NOT EXISTS payment_events (
  id CHAR(36) NOT NULL PRIMARY KEY,
  payment_id CHAR(36) NOT NULL,
  event_type VARCHAR(64) NOT NULL,
  status VARCHAR(64) NOT NULL,
  amount INT NULL,
  provider_event_id VARCHAR(128) NULL,
  payload_json LONGTEXT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_payment_events_payment
    FOREIGN KEY (payment_id) REFERENCES payments(id)
    ON DELETE CASCADE
);

CREATE INDEX idx_payment_events_payment_id ON payment_events(payment_id);
CREATE INDEX idx_payment_events_provider_event_id ON payment_events(provider_event_id);
