-- =============================================================================
-- Merchant & Acquiring Microservice Schema
-- Context: Merchants, POS Terminals, IPG Gateways, Settlement Accounts
-- =============================================================================

-- 1. Merchants Table
CREATE TABLE IF NOT EXISTS merchant_svc.merchants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_code VARCHAR(30) UNIQUE NOT NULL,
    business_name VARCHAR(150) NOT NULL,
    mcc VARCHAR(4) NOT NULL, -- Merchant Category Code (e.g. 5411: Supermarket, 5812: Restaurant)
    settlement_iban VARCHAR(34) NOT NULL, -- Settlement destination account
    contact_phone VARCHAR(15) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'TERMINATED')),
    risk_level VARCHAR(20) NOT NULL DEFAULT 'LOW' CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed Initial Test Merchants
INSERT INTO merchant_svc.merchants (merchant_code, business_name, mcc, settlement_iban, contact_phone, risk_level)
VALUES 
    ('MERC_DIGIKALA', 'Digikala Online Retail', '5311', 'IR120120000000001234567890', '02161930000', 'LOW'),
    ('MERC_SNAPP', 'Snapp Mobility Solutions', '4121', 'IR980120000000009876543210', '02196642', 'LOW'),
    ('MERC_RESTAURANT', 'Nayeb Express Tehran', '5812', 'IR550120000000005555555555', '02188776655', 'LOW')
ON CONFLICT (merchant_code) DO NOTHING;

-- 2. Terminals (POS Devices & Internet Payment Gateways)
CREATE TABLE IF NOT EXISTS merchant_svc.terminals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchant_svc.merchants(id) ON DELETE CASCADE,
    terminal_number VARCHAR(20) UNIQUE NOT NULL,
    terminal_type VARCHAR(20) NOT NULL CHECK (terminal_type IN ('POS_PHYSICAL', 'IPG_GATEWAY', 'MPOS')),
    serial_number VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'DISABLED')),
    province VARCHAR(50) NOT NULL DEFAULT 'Tehran',
    city VARCHAR(50) NOT NULL DEFAULT 'Tehran',
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Transactional Outbox Table
CREATE TABLE IF NOT EXISTS merchant_svc.outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(50) NOT NULL DEFAULT 'Merchant',
    aggregate_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_merchants_mcc ON merchant_svc.merchants (mcc);
CREATE INDEX IF NOT EXISTS idx_terminals_merchant ON merchant_svc.terminals (merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_outbox_unprocessed ON merchant_svc.outbox_events (created_at) WHERE processed_at IS NULL;
