# Changelog

## 0.3.0 (2026-11-24)

Updates the SDK to the public API contract 0.3.0 (94 operations, `spec/openapi.json`).

### Breaking

- **`invoice_package.summary`**: `total` is now a decimal string such as `"1234.50"`, not a number.
- **`companies.update`** no longer sends `taxId` (the CNPJ is immutable; the contract removed it).
- **Nullable fields.** Company (`tradeName`, address fields, `municipalReg`, `defaultServiceCode`, tax rates) and invoice (`emailStatus`, `lastEmailStatus`, `cancellationReason`, `portalFlag`) fields can be `nil`; `invoices.calculate` `classification`, `applicability` and `calculation` can be `nil`. `nfseNumber`, `dpsNumber` and `DpsSequence#lastNumber` are integers. `error.details` in a batch result can be an Array of issues or a Hash. `billing.plan` `stripe_subscription` is a boolean and `pix_subscription` a Hash or `nil`.
- `invoices.send_email` and `imports.emit` send no body when called without parameters.

- **Plan slugs.** `developer`, `growth`, `scale` and `volume` no longer exist: the slugs are `free`, `solo`, `equipe`, `empresa` and `escala` (plus `self-hosted`). Read `slug` as an open string; docs and tests changed.
- **`invoices.create` with `options.type` `SCHEDULE`** no longer returns an invoice: it returns a `Types::Schedule` (snake_case fields). `RECURRING` (with `options.recurrence`) behaves the same way. `IMMEDIATE` still returns a `Types::Invoice`.
- **`credits.balance`**: `Types::CreditBalance` lost `tenantId`, `overageUnits` and `overageAmountCents`; it now has `balance`, `planRemaining`, `avulsoBalance` and `hardLimit`.
- **`billing.plan`**: `usage.overage_units` and `usage.overage_amount_cents` are gone; `usage.avulso_balance` is new, and `subscription` has `stripe_portal_available`, `stripe_subscription` and `pix_subscription`. A workspace without a plan answers 404 with `code` `NO_PLAN_ASSIGNED`.
- **Purchase preview** is `GET /credits/purchase/preview?units=N`: use `credits.preview_purchase(units:)`.
- **Types follow the contract exactly.** `Types::Invoice` lost `documentKeyVersion` and gained `substitutesInvoiceId`, `substitutionDescription` and `portalFlag`; `Types::Company` lost `deletedAt` and gained `simplesIssRate`, `simplesRate`, `municipalityAgreement` and `warnings`; `Types::InvoiceEvent` gained `source`, `portalEvent` and `portalNsu`; `Types::Webhook` gained `environment`.
- **Webhooks and environments.** A `corvo_test_` key can no longer see or reach live webhooks, deliveries and integration connections: use a `corvo_live_` key to manage live ones. Webhook URLs that resolve to private networks are refused by the API. `Webhooks::EVENTS` has 12 events (`nfse.invoice.taker_rejected` added).

### Added (53 operations)

- **Public plans endpoints** (no API key): `plans.list` (`GET /plans`) and `plans.get(slug)` (`GET /plans/{slug}`), both with `cycle:` (`monthly` or `annual`), returning `Types::PlanPrice` (`monthlyEquivalentCents`, `chargeTotalCents`; replaces `Types::PlanQuote`).

- `customers` (`search`, `iterate`, `get`, `update`, `remove`), `cnpj.lookup`, `service_favorites` (`list`, `create`, `remove`).
- `accountant_package` (`get`, `update`, `send_package`, `list_sends`) and `invoice_package` (`summary`, `download` ZIP).
- `invoices`: `substitute`, `overview`, `review`; `list`/`iterate` accept `customerTaxId`; `send_email` accepts `email:`.
- `schedules` (`list`, `iterate`, `get`, `update`, `pause`, `resume`, `cancel`, `runs`, `iterate_runs`).
- `imports` (`start` multipart, `list`, `get`, `emit`, `rows`, `iterate_rows`, `update_row`, `discard`, `download_template`, `download_errors`).
- `fiscal_profiles`, `service_tax_profiles`, `dps_sequence`, `fiscal_portal.status`.
- `integrations.list_providers`, `integration_connections` (12 methods) and `integration_operations` (`complete_customer`, `retry`).
- `credits.preview_purchase`; `Types::INVOICE_STATUSES` (the 10 statuses).
- Contract coverage test: `spec/openapi.json` is vendored and every operationId must be implemented and send the documented method, path, query, body and `Idempotency-Key`.
- `User-Agent: corvo-nfse-ruby/<version>` header; `CorvoNfse::API_CONTRACT_VERSION`.
- Types can declare nested typed members (`CnpjProfile#address`, `ImportJob#counters`, `Company#municipalityAgreement`, ...); everything else stays a raw wire hash.
- RuboCop lint in CI.

### Changed

- Multipart bodies are built as binary, so `.xlsx` files and certificates with non-UTF-8 bytes are sent intact.
- README rewritten for the new resources and the new plans.

## 0.2.0

First contract the SDKs were written for.
