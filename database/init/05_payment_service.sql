-- =============================================================================
-- Payment Processing & Switch Microservice Schema
-- Context: High-Throughput Payments, Idempotency, Telemetry & Fraud Context
-- =============================================================================

-- 1. Payments Table
CREATE TABLE IF NOT EXISTS payment_svc.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key VARCHAR(128) UNIQUE NOT NULL,
    tracking_number VARCHAR(32) UNIQUE NOT NULL, -- RRN (Retrieval Reference Number)
    channel VARCHAR(30) NOT NULL CHECK (channel IN ('MOBILE_APP', 'INTERNET_BANKING', 'POS_TERMINAL', 'PAYMENT_GATEWAY', 'ATM', 'BATCH_PAYA')),
    payment_type VARCHAR(30) NOT NULL CHECK (payment_type IN ('CARD_TO_CARD', 'INTERNAL_TRANSFER', 'PURCHASE', 'BILL_PAYMENT', 'TOPUP', 'PAYA_TRANSFER', 'SATNA_TRANSFER')),
    source_account_id UUID,
    source_card_id UUID,
    destination_account_iban VARCHAR(34),
    destination_card_masked VARCHAR(19),
    amount NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    fee NUMERIC(18, 4) NOT NULL DEFAULT 0.0000,
    currency VARCHAR(3) NOT NULL DEFAULT 'IRR',
    status VARCHAR(30) NOT NULL DEFAULT 'INITIATED' CHECK (status IN ('INITIATED', 'PROCESSING', 'COMPLETED', 'FAILED', 'REVERSED', 'SUSPICIOUS_HELD')),
    failure_code VARCHAR(50),
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

-- 2. Payment Telemetry & Fraud Context (The Gold Mine for Data Science / ML)
CREATE TABLE IF NOT EXISTS payment_svc.payment_telemetry (
    payment_id UUID PRIMARY KEY REFERENCES payment_svc.payments(id) ON DELETE CASCADE,
    ip_address VARCHAR(45) NOT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'Iran',
    city VARCHAR(50),
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    device_id VARCHAR(100) NOT NULL,
    device_model VARCHAR(100),
    os_name VARCHAR(50), -- e.g. Android, iOS, Windows
    os_version VARCHAR(50),
    app_version VARCHAR(20),
    is_vpn_detected BOOLEAN NOT NULL DEFAULT false,
    is_rooted_or_jailbroken BOOLEAN NOT NULL DEFAULT false,
    is_emulator BOOLEAN NOT NULL DEFAULT false,
    fraud_risk_score NUMERIC(5, 2) NOT NULL DEFAULT 0.00, -- 0.00 (Safe) to 100.00 (High Fraud Risk)
    is_flagged_as_fraud BOOLEAN NOT NULL DEFAULT false,
    fraud_rule_triggered VARCHAR(100), -- e.g. 'IMPOSSIBLE_SPEED_GEO', 'UNUSUAL_MIDNIGHT_HIGH_AMOUNT'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Transactional Outbox Table
CREATE TABLE IF NOT EXISTS payment_svc.outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(50) NOT NULL DEFAULT 'Payment',
    aggregate_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_payments_source_account ON payment_svc.payments (source_account_id, created_at);
CREATE INDEX IF NOT EXISTS idx_payments_tracking ON payment_svc.payments (tracking_number);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payment_svc.payments (created_at);
CREATE INDEX IF NOT EXISTS idx_payment_telemetry_device ON payment_svc.payment_telemetry (device_id);
CREATE INDEX IF NOT EXISTS idx_payment_telemetry_ip ON payment_svc.payment_telemetry (ip_address);
CREATE INDEX IF NOT EXISTS idx_payment_telemetry_fraud ON payment_svc.payment_telemetry (is_flagged_as_fraud) WHERE is_flagged_as_fraud = true;
CREATE INDEX IF NOT EXISTS idx_payment_outbox_unprocessed ON payment_svc.outbox_events (created_at) WHERE processed_at IS NULL;
