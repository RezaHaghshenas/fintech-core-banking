-- =============================================================================
-- Customer & KYC Microservice Schema
-- Context: Customer Identity, Tiering, KYC verification, Risk profile
-- =============================================================================

-- 1. Customers Table
CREATE TABLE IF NOT EXISTS customer_svc.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    national_id VARCHAR(10) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    date_of_birth DATE NOT NULL,
    kyc_tier INT NOT NULL DEFAULT 1 CHECK (kyc_tier IN (1, 2, 3)), -- 1: Basic, 2: Standard, 3: Verified VIP
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'BLOCKED')),
    risk_score NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    version INT NOT NULL DEFAULT 1
);

-- 2. Customer Addresses
CREATE TABLE IF NOT EXISTS customer_svc.customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customer_svc.customers(id) ON DELETE CASCADE,
    address_type VARCHAR(20) NOT NULL DEFAULT 'HOME' CHECK (address_type IN ('HOME', 'WORK')),
    postal_code VARCHAR(10) NOT NULL,
    province VARCHAR(50) NOT NULL,
    city VARCHAR(50) NOT NULL,
    full_address TEXT NOT NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    is_primary BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. KYC Verifications
CREATE TABLE IF NOT EXISTS customer_svc.kyc_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customer_svc.customers(id) ON DELETE CASCADE,
    document_type VARCHAR(30) NOT NULL CHECK (document_type IN ('NATIONAL_CARD', 'BIRTH_CERTIFICATE', 'PASSPORT', 'SELFIE_LIVENESS')),
    document_url VARCHAR(500) NOT NULL,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (verification_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    rejection_reason TEXT,
    verified_by VARCHAR(100),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Transactional Outbox Table (for CDC / Kafka event streaming)
CREATE TABLE IF NOT EXISTS customer_svc.outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(50) NOT NULL DEFAULT 'Customer',
    aggregate_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customer_svc.customers (phone_number);
CREATE INDEX IF NOT EXISTS idx_customers_national_id ON customer_svc.customers (national_id);
CREATE INDEX IF NOT EXISTS idx_customer_addresses_customer_id ON customer_svc.customer_addresses (customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_outbox_unprocessed ON customer_svc.outbox_events (created_at) WHERE processed_at IS NULL;
