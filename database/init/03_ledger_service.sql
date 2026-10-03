-- =============================================================================
-- Core Banking & Double-Entry Ledger Microservice Schema
-- Context: Accounts, Double-Entry Journal, Partitioned Lines, Account Holds
-- =============================================================================

-- 1. Chart of Accounts (COA - Accounting Classification)
CREATE TABLE IF NOT EXISTS ledger_svc.chart_of_accounts (
    code VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(20) NOT NULL CHECK (category IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    description TEXT
);

-- Seed Essential Chart of Accounts
INSERT INTO ledger_svc.chart_of_accounts (code, name, category, description)
VALUES 
    ('1000', 'Cash & Central Bank Reserves', 'ASSET', 'Bank cash vault and central bank deposits'),
    ('2000', 'Customer Deposits (Current)', 'LIABILITY', 'Demand deposits owned by customers'),
    ('2010', 'Customer Deposits (Savings)', 'LIABILITY', 'Savings accounts bearing interest'),
    ('4000', 'Transaction Fee Revenue', 'REVENUE', 'Earnings from transfer and card fees'),
    ('5000', 'Operational Expense', 'EXPENSE', 'Interbank switch fees and costs')
ON CONFLICT (code) DO NOTHING;

-- 2. Bank Accounts Table
CREATE TABLE IF NOT EXISTS ledger_svc.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL, -- Logical ref to customer_svc.customers
    account_number VARCHAR(20) UNIQUE NOT NULL,
    iban VARCHAR(34) UNIQUE NOT NULL, -- e.g. IR...
    coa_code VARCHAR(10) NOT NULL REFERENCES ledger_svc.chart_of_accounts(code),
    currency VARCHAR(3) NOT NULL DEFAULT 'IRR',
    account_type VARCHAR(30) NOT NULL CHECK (account_type IN ('CHECKING', 'SAVINGS', 'ESCROW', 'SETTLEMENT', 'INTERNAL_SYSTEM')),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'FROZEN', 'BLOCKED', 'CLOSED', 'DORMANT')),
    balance NUMERIC(18, 4) NOT NULL DEFAULT 0.0000, -- Cached total balance
    available_balance NUMERIC(18, 4) NOT NULL DEFAULT 0.0000, -- Balance minus active holds
    daily_transfer_limit NUMERIC(18, 4) NOT NULL DEFAULT 1000000000.0000, -- 1 Billion Rials
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    version BIGINT NOT NULL DEFAULT 1 -- Concurrency check
);

-- 3. Journal Entries (The Master Accounting Record)
CREATE TABLE IF NOT EXISTS ledger_svc.journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_id VARCHAR(100) UNIQUE NOT NULL, -- External business transaction ID (Idempotency key)
    entry_type VARCHAR(50) NOT NULL CHECK (entry_type IN ('TRANSFER', 'CARD_PURCHASE', 'DEPOSIT', 'WITHDRAWAL', 'FEE_CHARGE', 'REVERSAL')),
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'POSTED' CHECK (status IN ('DRAFT', 'POSTED', 'REVERSED')),
    posted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Journal Entry Lines (Partitioned by Month for Enterprise Scale)
CREATE TABLE IF NOT EXISTS ledger_svc.journal_entry_lines (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    journal_entry_id UUID NOT NULL,
    account_id UUID NOT NULL REFERENCES ledger_svc.accounts(id),
    direction VARCHAR(6) NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
    amount NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'IRR',
    balance_after NUMERIC(18, 4) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Partitions for 2025 and 2026
CREATE TABLE IF NOT EXISTS ledger_svc.journal_entry_lines_2025 PARTITION OF ledger_svc.journal_entry_lines
    FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');

CREATE TABLE IF NOT EXISTS ledger_svc.journal_entry_lines_2026 PARTITION OF ledger_svc.journal_entry_lines
    FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');

CREATE TABLE IF NOT EXISTS ledger_svc.journal_entry_lines_2027 PARTITION OF ledger_svc.journal_entry_lines
    FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');

-- 5. Account Holds (مسدودی موقت یا قضایی وجه)
CREATE TABLE IF NOT EXISTS ledger_svc.account_holds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES ledger_svc.accounts(id),
    amount NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    hold_reason VARCHAR(100) NOT NULL, -- e.g. 'CARD_AUTH_PENDING', 'JUDICIAL_ORDER'
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'RELEASED', 'CAPTURED')),
    reference_id VARCHAR(100),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Transactional Outbox Table
CREATE TABLE IF NOT EXISTS ledger_svc.outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(50) NOT NULL DEFAULT 'Ledger',
    aggregate_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_accounts_customer_id ON ledger_svc.accounts (customer_id);
CREATE INDEX IF NOT EXISTS idx_accounts_account_number ON ledger_svc.accounts (account_number);
CREATE INDEX IF NOT EXISTS idx_accounts_iban ON ledger_svc.accounts (iban);
CREATE INDEX IF NOT EXISTS idx_journal_entries_reference_id ON ledger_svc.journal_entries (reference_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account_id ON ledger_svc.journal_entry_lines (account_id, created_at);
CREATE INDEX IF NOT EXISTS idx_account_holds_active ON ledger_svc.account_holds (account_id) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_ledger_outbox_unprocessed ON ledger_svc.outbox_events (created_at) WHERE processed_at IS NULL;
