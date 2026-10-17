# corvo-nfse

Ruby SDK for the [Corvo](https://corvo.tech) NFS-e API. Register companies, calculate taxes, issue Brazilian service invoices (NFS-e), follow them by webhook and download the PDF and XML, from Ruby 3.2+.

- **Result-style returns.** Every call returns `[data, error]` where exactly one is `nil`. API, network and timeout failures are values, never raised. The error carries the server's stable `code`, the HTTP `status`, the `request_id`, field-level `details` and `retry_after`.
- **Pagination built in.** Lists return `Types::Paginated`, and `iterate` walks every page.
- **Safe retries.** Issuing an invoice and sending an email accept an idempotency key.
- **Webhook signature check** in constant time.
- **No runtime dependencies**: it uses `net/http`, `uri`, `json` and `openssl` from the standard library. Library only, no CLI.

Full API reference: <https://corvo.tech/en/api-docs>.

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
  taxRegime: "Simples Nacional",   # "MEI" | "Simples Nacional" | "Lucro Presumido" | "Lucro Real"
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

Use `options: { type: "SCHEDULE" }` with a future `competenceDate` to schedule the issuance. Parameters and response fields use the API's camelCase wire format, unchanged.

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

`CorvoNfse::Webhooks::EVENTS` lists the 9 events you can subscribe to. The `webhook.test` event is only sent by `client.webhooks.test`.

## Resources

| Namespace | Methods |
| --- | --- |
| `client.companies` | `create`, `get`, `update`, `remove`, `list`, `iterate` |
| `client.certificates` | `upload`, `list`, `remove` |
| `client.invoices` | `create`, `calculate`, `get`, `list`, `iterate`, `events`, `pdf`, `xml`, `download_url`, `send_email` |
| `client.webhooks` | `list`, `create`, `remove`, `test`, plus `deliveries.list/iterate/stats/retry` |
| `client.credits` | `balance`, `plans`, `history`, `iterate_history` |
| `client.billing` | `plan`, `usage` |
| `client.plans` | `list`, `get`, `quote` (public price catalog) |
| `client.health` | `live`, `ready` |

Changing plans and the billing portal exist only in the dashboard, so they are not in the SDK. Immutable response types live under `CorvoNfse::Types` as `Data` classes whose members mirror the wire format (for example `Types::Invoice#accessKey`).

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
bundle exec rspec   # the contract spec is pending without env
```

The contract spec runs only when `CORVO_API_KEY` and `CORVO_BASE_URL` point to a reachable instance.

## License

MIT, see [LICENSE](LICENSE).
