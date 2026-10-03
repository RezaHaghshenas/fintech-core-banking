-- =============================================================================
-- Core Database Setup: Extensions and Schema Definitions
-- Architecture: Database-per-Service (Isolated Schemas with Outbox Pattern)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Schemas for each microservice boundary
CREATE SCHEMA IF NOT EXISTS customer_svc;
CREATE SCHEMA IF NOT EXISTS ledger_svc;
CREATE SCHEMA IF NOT EXISTS card_svc;
CREATE SCHEMA IF NOT EXISTS payment_svc;
CREATE SCHEMA IF NOT EXISTS merchant_svc;
