-- =============================================================================
-- Card Management Microservice (CMS) Schema
-- Context: Physical/Virtual Cards, Encrypted PIN/CVV hashes, Card Limits
-- =============================================================================

-- 1. Cards Table
CREATE TABLE IF NOT EXISTS card_svc.cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL, -- Logical ref to ledger_svc.accounts
    customer_id UUID NOT NULL, -- Logical ref to customer_svc.customers
    card_number_masked VARCHAR(19) NOT NULL, -- e.g. '603799******1234'
    card_number_hash VARCHAR(64) UNIQUE NOT NULL, -- SHA-256 for fast lookup
    card_type VARCHAR(20) NOT NULL DEFAULT 'DEBIT' CHECK (card_type IN ('DEBIT', 'VIRTUAL', 'GIFT', 'CREDIT')),
    cvv2_hash VARCHAR(64) NOT NULL,
    expiry_month INT NOT NULL CHECK (expiry_month BETWEEN 1 AND 12),
    expiry_year INT NOT NULL,
    pin1_hash VARCHAR(64), -- ATM 4-digit PIN
    pin2_hash VARCHAR(64), -- Internet Dynamic / Static PIN
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING_ACTIVATION', 'ACTIVE', 'FROZEN', 'BLOCKED', 'EXPIRED', 'STOLEN')),
    failed_pin_attempts INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    version INT NOT NULL DEFAULT 1
);

-- 2. Card Channel Limits (Dynamic Limits per Channel)
CREATE TABLE IF NOT EXISTS card_svc.card_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES card_svc.cards(id) ON DELETE CASCADE,
    daily_atm_limit NUMERIC(18, 4) NOT NULL DEFAULT 10000000.0000, -- 10M Rials
    daily_pos_limit NUMERIC(18, 4) NOT NULL DEFAULT 500000000.0000, -- 500M Rials
    daily_internet_limit NUMERIC(18, 4) NOT NULL DEFAULT 250000000.0000, -- 250M Rials
    is_international_enabled BOOLEAN NOT NULL DEFAULT false,
    is_internet_payment_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Card Security Tokens (For In-App / Contactless NFC Wallets)
CREATE TABLE IF NOT EXISTS card_svc.card_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES card_svc.cards(id) ON DELETE CASCADE,
    token_value VARCHAR(64) UNIQUE NOT NULL,
    device_fingerprint VARCHAR(128) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'REVOKED')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Transactional Outbox Table
CREATE TABLE IF NOT EXISTS card_svc.outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(50) NOT NULL DEFAULT 'Card',
    aggregate_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_cards_customer_id ON card_svc.cards (customer_id);
CREATE INDEX IF NOT EXISTS idx_cards_account_id ON card_svc.cards (account_id);
CREATE INDEX IF NOT EXISTS idx_cards_hash ON card_svc.cards (card_number_hash);
CREATE INDEX IF NOT EXISTS idx_card_outbox_unprocessed ON card_svc.outbox_events (created_at) WHERE processed_at IS NULL;
