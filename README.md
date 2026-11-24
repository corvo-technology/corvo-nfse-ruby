# corvo-nfse

Ruby SDK for the [Corvo](https://corvo.tech) NFS-e API. Register companies, calculate taxes, issue Brazilian service invoices (NFS-e), follow them by webhook and download the PDF and XML, from Ruby 3.2+.

- **Result-style returns.** Every call returns `[data, error]` where exactly one is `nil`. API, network and timeout failures are values, never raised. The error carries the server's stable `code`, the HTTP `status`, the `request_id`, field-level `details` and `retry_after`.
- **Pagination built in.** Lists return `Types::Paginated`, and `iterate` walks every page.
- **Safe retries.** Issuing an invoice and sending an email accept an idempotency key.
- **Webhook signature check** in constant time.
- **No runtime dependencies**: it uses `net/http`, `uri`, `json` and `openssl` from the standard library. Library only, no CLI.

Full API reference: <https://corvo.tech/en/docs>. The machine-readable contract (OpenAPI 3.0, version 0.3.0, 94 operations) is at <https://corvo.tech/openapi.json>; this SDK covers all of it.

## Installation

```bash
gem install corvo-nfse
```

Or in your `Gemfile`:

```ruby
gem "corvo-nfse"
```

## Quickstart

Start with a `corvo_test_...` key: invoices issued with it have no fiscal value.

```ruby
require "corvo_nfse"

client = CorvoNfse::Client.new(api_key: "corvo_test_...") # or set CORVO_API_KEY

page, error = client.companies.list(limit: 10)

if error
  warn "#{error.code}: #{error.message} (HTTP #{error.status}, request #{error.request_id})"
else
  page.data.each { |company| puts company.legalName }
end
```

`Client.new` is the only call that raises (`ArgumentError`): it fails fast when no API key is configured or the base URL is invalid. `iterate` also raises, see below.

### Register a company

```ruby
company, error = client.companies.create(
  legalName: "Empresa Exemplo Ltda",
  taxId: "11222333000181",
  taxRegime: "Simples Nacional",   # "MEI" | "Simples Nacional" (the only regimes Corvo serves)
  simplesRate: "6.54",             # required for Simples Nacional: effective DAS rate (%), ignored for MEI
  municipalityCode: "3550308",     # IBGE code, 7 digits
  defaultServiceCode: "010101"     # optional: used when an invoice omits service.code
)
```

In `live`, also upload the A1 certificate. The company is ready when `company.status == "ready"` and `company.setupGaps` is empty.

```ruby
p12 = File.binread("certificado.p12")
cert, error = client.certificates.upload(company.id, p12, "senha-do-certificado")
```

### Estimate the taxes before issuing

Nothing is issued, stored or charged.

```ruby
estimate, error = client.invoices.calculate(
  companyTaxId: "11222333000181",
  service: { description: "Consultoria" },
  amount: 1500,
  competenceDate: "2026-10-16"
)
# estimate["status"] is "ready" or "blocked": a fiscal gap is data, not an error.
```

### Issue an invoice

Issuing is asynchronous: a successful call means the request was accepted, not that the invoice is authorized. Follow the status with `invoices.get` or webhooks.

```ruby
invoice, error = client.invoices.create(
  {
    companyTaxId: "11222333000181", # or companyId
    # customer is optional; when sent, taxId (CPF or CNPJ) is required.
    customer: { taxId: "52998224725", name: "Cliente", email: "cliente@example.com" },
    service: { description: "Consultoria" }, # code and city default to the company's
    amount: 150.5,
    competenceDate: "2026-10-16",
    options: { email: { send: true } }
  },
  idempotency_key: "order-42" # the same key never issues twice
)

raise error if error # CorvoNfse::CorvoApiError is safe to raise
puts invoice.id
```

Parameters and response fields use the API's camelCase wire format, unchanged (billing, schedules and imports answer in snake_case, also unchanged).

### Schedule or repeat an invoice

With `options: { type: "SCHEDULE" }` (once) or `"RECURRING"`, `create` returns a `Types::Schedule` instead of an invoice (snake_case fields). The note only exists when the schedule runs (09:00 America/Sao_Paulo, Monday to Friday); `competenceDate` is the date of the first run and must be from tomorrow on.

```ruby
schedule, error = client.invoices.create(
  {
    companyTaxId: "11222333000181",
    service: { description: "Mensalidade" }, amount: 300, competenceDate: "2026-12-01",
    options: { type: "RECURRING", recurrence: { frequency: "MONTHLY", endsOn: "2027-06-30" } }
  }
)
puts schedule.next_run_on

client.schedules.pause(schedule.id)
client.schedules.resume(schedule.id)
runs, = client.schedules.runs(schedule.id) # every attempt, newest first
client.schedules.cancel(schedule.id)       # final
```

### Look up a CNPJ, saved customers and favorite services

```ruby
profile, error = client.cnpj.lookup("11222333000181") # legalName, situation, simples, address...

page, error = client.customers.search(search: "acme", limit: 20)
customer, = client.customers.get("11222333000181")
client.customers.update("11222333000181", name: "Acme S.A.", email: nil)
client.customers.remove("11222333000181") # issued invoices are not changed

client.service_favorites.create(company.id, label: "Consultoria", description: "Consultoria em TI", serviceCode: "01.01")
favorites, = client.service_favorites.list(company.id)
```

### Substitute an invoice and send it to another e-mail

```ruby
new_invoice, error = client.invoices.substitute(
  "inv_1", { description: "Corrigindo a descrição do serviço", service: { description: "Consultoria mensal" } },
  idempotency_key: "sub-inv_1"
)
client.invoices.send_email("inv_1", email: "financeiro@cliente.com.br", idempotency_key: "mail-inv_1")
client.invoices.list(customerTaxId: "52998224725")
```

### Monthly package for the accountant

```ruby
client.accountant_package.update(company.id, "contador@exemplo.com.br") # nil turns the monthly send off
client.accountant_package.send_package(company.id, month: "2026-10")
sends, = client.accountant_package.list_sends(company.id)

summary, = client.invoice_package.summary(company.id, month: "2026-10")
zip, = client.invoice_package.download(company.id, month: "2026-10") # xml/, pdf/ and resumo.csv
File.binwrite("pacote.zip", zip.content)
```

### Import a spreadsheet

```ruby
job, error = client.imports.start(File.binread("notas.xlsx"), file_name: "notas.xlsx", company_id: company.id)
job, = client.imports.get(job.id) until job.status != "processing" # then "ready"
client.imports.rows(job.id, status: "invalid").first.data.each { |row| puts "#{row.line}: #{row.error_message}" }
client.imports.update_row(job.id, 3, { amount: 150 })
client.imports.emit(job.id, send_email: true)
template, = client.imports.download_template # CSV
```

Also available: `client.dps_sequence`, `client.fiscal_profiles`, `client.service_tax_profiles`, `client.fiscal_portal`, and the payment-platform integrations (`client.integrations`, `client.integration_connections`, `client.integration_operations`). See the table below.

To declare a deduction from the ISS base, send `deduction:` (greater than 0 and less than `amount` minus `discount`). The invoice is still issued for the full `amount`, and you are responsible for the declared value.

### Issue up to 50 invoices at once

`create_batch` takes 1 to 50 items (they can belong to different companies). Items are checked one by one: valid ones are saved together, invalid ones come back `rejected` and are not saved. Send an `idempotencyKey` per item, so repeating the batch after a timeout returns the saved ones with `replayed`.

```ruby
batch, error = client.invoices.create_batch(
  [
    { companyTaxId: "11222333000181", idempotencyKey: "sheet-row-2",
      service: { description: "Consultoria" }, amount: 150.5, competenceDate: "2026-10-16" },
    { companyTaxId: "11222333000181", idempotencyKey: "sheet-row-3",
      service: { description: "Manutenção" }, amount: 300, competenceDate: "2026-10-16" }
  ]
)
batch.results.select { |r| r.status == "rejected" }.each do |r|
  puts "#{r.index} #{r.error["code"]} #{r.error["message"]}"
end
```

The route allows 10 batches per minute per tenant (`429` with `Retry-After`).

### Cancel an invoice

```ruby
invoice, error = client.invoices.cancel(
  "inv_1", reason: "issue_error", description: "Wrong amount on the invoice"
) # reason: "issue_error" | "service_not_provided" | "other"
```

- `queued`: cancelled at once, `status` is `"cancelled"` with `cancelledAt` set.
- `authorized`: `status` is `"cancelling"` while the cancellation is processed at the Sefin. The issuance credit is not refunded.
- `processing`: stays `"processing"` with `cancellationRequestedAt` set and is cancelled once authorized.

`description` (15 to 255 characters) is required for an authorized or processing invoice and optional for a queued one. Read the invoice again (or listen to the `nfse.invoice.cancelled` and `nfse.invoice.cancellation_rejected` webhooks) to see the outcome: `cancelled`, or back to `authorized` with `lastErrorCode` when the cancellation was rejected.

### Walk every page

```ruby
client.invoices.iterate(companyId: "c_1", status: "authorized") do |inv|
  puts inv.nfseNumber
end

client.companies.iterate(limit: 100).lazy.map(&:taxId).first(5) # or lazily, as an Enumerator
```

`iterate` is the one method that raises: a failed page raises `CorvoNfse::CorvoApiError`, since a block or an Enumerator has no slot for a result.

### Download the PDF or XML

The invoice must be `authorized` and have its documents ready.

```ruby
file, error = client.invoices.pdf("inv_1")
File.binwrite("nfse.pdf", file.content) unless error # also file.mime_type and file.file_name
```

### Verify webhook signatures

```ruby
raw = request.body.read # the raw bytes: do not re-serialize the JSON
sig = request.env["HTTP_X_CORVO_SIGNATURE"]

if CorvoNfse::Webhooks.verify_signature(raw, sig, secret)
  # authentic; deduplicate by the event id, the same event can arrive twice
else
  # reject with 400
end
```

`CorvoNfse::Webhooks::EVENTS` lists the 12 events you can subscribe to (including `nfse.invoice.taker_rejected`). A webhook created with a `corvo_test_` key only receives test events and cannot see live ones; webhook URLs that resolve to private or loopback networks are refused. The `webhook.test` event is only sent by `client.webhooks.test`.

## Resources

| Namespace | Methods |
| --- | --- |
| `client.companies` | `create`, `get`, `update`, `remove`, `list`, `iterate` |
| `client.certificates` | `upload`, `list`, `remove` |
| `client.invoices` | `create` (invoice or schedule), `create_batch`, `calculate`, `get`, `list`, `iterate`, `events`, `pdf`, `xml`, `download_url`, `send_email`, `cancel`, `substitute`, `overview`, `review` |
| `client.schedules` | `list`, `iterate`, `get`, `update`, `pause`, `resume`, `cancel`, `runs`, `iterate_runs` |
| `client.imports` | `start`, `list`, `get`, `emit`, `rows`, `iterate_rows`, `update_row`, `discard`, `download_template`, `download_errors` |
| `client.customers` | `search`, `iterate`, `get`, `update`, `remove` |
| `client.cnpj` | `lookup` |
| `client.service_favorites` | `list`, `create`, `remove` |
| `client.accountant_package` | `get`, `update`, `send_package`, `list_sends` |
| `client.invoice_package` | `summary`, `download` |
| `client.dps_sequence` | `get`, `set` |
| `client.fiscal_profiles` | `list`, `upsert`, `approve` |
| `client.service_tax_profiles` | `list`, `create`, `update`, `remove`, `approve` |
| `client.fiscal_portal` | `status` |
| `client.integrations` | `list_providers` |
| `client.integration_connections` | `list`, `create`, `get`, `validate`, `update_credentials`, `activate`, `pause`, `disconnect`, `list_rules`, `replace_rules`, `list_events`, `list_operations` |
| `client.integration_operations` | `complete_customer`, `retry` |
| `client.webhooks` | `list`, `create`, `remove`, `test`, plus `deliveries.list/iterate/stats/retry` |
| `client.credits` | `balance`, `plans`, `history`, `iterate_history`, `preview_purchase` |
| `client.billing` | `plan`, `usage` |
| `client.plans` | `list`, `get` (public prices, no API key; `cycle: "annual"` for the discounted price), `quote` (outside the contract) |
| `client.health` | `live`, `ready` |

Every operationId of the contract maps to one of these methods: the table is in `spec/support_operations.rb` and `spec/contract/operations_spec.rb` fails when `spec/openapi.json` gains an operation the SDK does not implement.

Plans are `free`, `solo`, `equipe`, `empresa` and `escala` (and `self-hosted` on a self-hosted instance); treat the slug as an open string and read the allowance from the plan. Credits are plan notes plus loose notes (`balance`, `planRemaining`, `avulsoBalance`); there is no overage billing, and `credits.preview_purchase(units: 10)` prices a one-off purchase (buying is done in the dashboard). Changing plans and the billing portal exist only in the dashboard, so they are not in the SDK. Immutable response types live under `CorvoNfse::Types` as `Data` classes whose members mirror the wire format (for example `Types::Invoice#accessKey`).

## Errors

`CorvoNfse::CorvoApiError` carries `status`, `code`, `message`, `details`, `request_id` and `retry_after`. `code` is the API's `ERROR_*` code, falling back to `http_<status>`; transport failures use `status = 0` and a `code` of `network_error`, `timeout` or `invalid_json`. On `429`, `retry_after` holds the seconds to wait.

## Configuration

```ruby
CorvoNfse::Client.new(
  api_key: "corvo_test_...",          # falls back to ENV["CORVO_API_KEY"]
  base_url: "https://api.corvo.tech", # falls back to ENV["CORVO_BASE_URL"], then the default
  prefix: "v1",
  timeout: 30,                        # open/read/write timeout, seconds
  allow_insecure_http: false          # http:// only for loopback and private hosts
)
```

Auth is the `X-API-Key` header. Keys are `corvo_test_...` or `corvo_live_...` and belong to one account and environment; the key decides the environment.

## Development

```bash
bundle install
bundle exec rspec     # unit tests with mocked HTTP + contract coverage
bundle exec rubocop   # lint
```

`spec/openapi.json` is a copy of the API contract. To update the SDK after an API change, replace it with the new `openapi.json` and run the specs: the coverage test lists every operation that is not implemented yet.

The live contract spec (`spec/contract/contract_spec.rb`) runs only when `CORVO_API_KEY` and `CORVO_BASE_URL` point to a reachable instance.

## License

MIT, see [LICENSE](LICENSE).
