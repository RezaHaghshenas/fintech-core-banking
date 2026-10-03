# NeoCore Bank - Distributed Core Banking & FinTech Data Platform 💳🏛️

An enterprise-grade, microservice-based Neo-Banking & Core Banking platform designed for high-throughput transactional integrity (ACID) and scalable Big Data analytics / ML Fraud Detection.

---

## 🏛️ Architecture Overview

The system implements the **Database-per-Service** pattern with **Transactional Outbox (CDC)** for reliable event streaming into analytics and fraud detection pipelines.

```
┌─────────────────────────┐   ┌─────────────────────────┐   ┌─────────────────────────┐
│  Customer & KYC Service │   │  Card Management (CMS)  │   │  Merchant & Terminal    │
│    (customer_svc)       │   │       (card_svc)        │   │     (merchant_svc)      │
└────────────┬────────────┘   └────────────┬────────────┘   └────────────┬────────────┘
             │                             │                             │
             └──────────────────────┬──────┴─────────────────────────────┘
                                    │
                                    ▼
                     ┌─────────────────────────────┐
                     │   Core Banking & Ledger     │
                     │  (Double-Entry Accounting)  │
                     │      (ledger_svc)           │
                     └──────────────┬──────────────┘
                                    │
                                    ▼
                     ┌─────────────────────────────┐
                     │    Payment & Switch Service │
                     │   (Paya / Satna / Card2Card)│
                     │      (payment_svc)          │
                     └──────────────┬──────────────┘
                                    │ Outbox Pattern (CDC)
                                    ▼
                      =============================
                        Apache Kafka (Event Stream)
                      =============================
                                    │
                                    ▼
                     ┌─────────────────────────────┐
                     │  Data & Fraud Analytics     │
                     │    (ClickHouse / Lakehouse) │
                     └─────────────────────────────┘
```

---

## 📦 Microservices Database Schemas

### 1. `customer_svc` (Identity, KYC & Customer Master)
* `customers`: Core identity, National ID (کد ملی), Tier levels (Tier 1-3), Risk scores, Statuses.
* `customer_addresses`: Address book, postal codes, and GPS coordinates for fraud location-matching.
* `kyc_verifications`: Document types, verification statuses, and compliance audit trail.
* `outbox_events`: Transactional outbox for event distribution.

### 2. `ledger_svc` (Core Banking & Double-Entry Accounting)
* `chart_of_accounts`: Standard COA hierarchy (Assets, Liabilities, Equity, Revenue, Expense).
* `accounts`: IBAN, Account numbers, balances, holds, and limits.
* `journal_entries`: Immutable financial journal entries (`reference_id` idempotency key).
* `journal_entry_lines`: **Monthly Partitioned** table (`2025`, `2026`, `2027`) storing debit and credit line movements (`SUM(Debits) == SUM(Credits)`).
* `account_holds`: Temporary authorizations and judicial freeze amounts.
* `outbox_events`: Financial movement events.

### 3. `card_svc` (Card Management Service - CMS)
* `cards`: Masked PAN, SHA-256 hashed PAN, encrypted CVV2/PIN hashes, statuses, and expiry.
* `card_limits`: Dynamic channel-based limits (ATM, POS, Internet, International).
* `card_tokens`: Digital wallet tokens (Apple Pay / Google Pay / In-App).
* `outbox_events`: Card lifecycle events.

### 4. `payment_svc` (Payment Switch & Transaction Engine)
* `payments`: High-throughput transfers (Card-to-Card, Paya, Satna, POS Purchases, Bill payments).
* `payment_telemetry`: Device fingerprint, IP address, GPS, VPN/Proxy flags, Root/Jailbreak detection, and ML Fraud Risk Score.
* `outbox_events`: Payment transaction events.

### 5. `merchant_svc` (Merchant Acquiring & POS Network)
* `merchants`: Registered businesses, MCC (Merchant Category Code), settlement accounts.
* `terminals`: Physical POS, IPG (Internet Payment Gateway), and MPOS terminals.
* `outbox_events`: Acquiring events.

---

## 🚀 Getting Started

### Prerequisites
* Docker & Docker Compose
* .NET SDK 9.0+

### Run Database Infrastructure
```bash
docker compose up -d
```
PostgreSQL will run on port `5433` with all schemas, tables, and partitions pre-initialized.