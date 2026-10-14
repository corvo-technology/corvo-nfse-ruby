# corvo-nfse

Ruby SDK for the [Corvo NFS-e API](https://corvo.tech) — electronic invoicing
(Nota Fiscal de Serviços Eletrônica) for Brazil.

A small, **stdlib-only** client (uses `net/http`, `uri`, `json`, `openssl` —
no runtime gems) that exposes the full Corvo surface with result-style
`[data, error]` returns and constant-time HMAC webhook verification.

- **Ruby:** 3.2+
- **Runtime dependencies:** none
- **Namespace:** `CorvoNfse`

Looking for the reference implementation or a CLI? See the canonical Node SDK,
[`corvo-nfse-node`](https://github.com/corvo-technology/corvo-nfse-node). This
gem is a library only (no CLI).

## Installation

```bash
gem install corvo-nfse
```

Or in your `Gemfile`:

```ruby
gem "corvo-nfse"
```

## Quickstart

```ruby
client = CorvoNfse::Client.new(api_key: "corvo_live_xxx") # or set CORVO_API_KEY

data, error = client.companies.create(
  legalName: "Empresa Exemplo Tecnologia LTDA",
  taxId: "41834687000148",
  taxRegime: "Simples Nacional"
)

if error
  warn "#{error.code}: #{error.message} (request #{error.request_id})"
else
  puts data.id          # => a CorvoNfse::Types::Company
  puts data.taxId
end
```

Every call returns `[data, error]` where **exactly one is `nil`** (a `204` /
empty body returns `[nil, nil]`). API, network, and timeout failures are
returned as values — they are **never raised**. Check `error` first.

## Result style

```ruby
invoice, error = client.invoices.create(
  {
    customer: { name: "ACME Ltda", taxId: "12345678000199" },
    service:  { code: "0107", municipalityCode: "3550308", description: "Consulting" },
    amount:   1500.0,
    competenceDate: "2026-10-01"
  },
  idempotency_key: "order-42"
)

raise error if error          # CorvoNfse::CorvoApiError — safe to raise
puts invoice.accessKey
```

`CorvoNfse::CorvoApiError` carries `status`, `code`, `message`, `details`,
`request_id`, and `retry_after`. Network/timeout failures use `status = 0` and a
`code` of `"network_error"` or `"timeout"`.

## Pagination & iteration

List endpoints return a `Types::Paginated` (`#data`, `#pagination`). The
pagination cursor is an opaque base64url string.

```ruby
page, error = client.invoices.list(companyId: "c_1", status: "authorized", limit: 25)
page.data.each { |inv| puts inv.id }
page.pagination.hasMore        # => true/false
page.pagination.nextCursor     # => opaque cursor or nil
```

To walk every page, use `iterate`. It accepts a block or returns an `Enumerator`:

```ruby
client.invoices.iterate(companyId: "c_1") do |inv|
  puts inv.id
end

# or lazily:
client.companies.iterate(limit: 100).lazy.map(&:taxId).first(5)
```

> **`iterate` is the one method that raises.** Because a block/Enumerator has no
> result slot for an error, a first-page (or any-page) failure raises
> `CorvoNfse::CorvoApiError` instead of returning a tuple.

## Resources

`client.companies` — `create`, `get`, `update`, `remove`, `list`, `iterate`
`client.certificates` — `upload` (multipart), `list`, `remove`
`client.invoices` — `create`, `get`, `list`, `iterate`, `events`, `pdf`, `xml`,
`download_url`, `send_email`
`client.webhooks` — `list`, `create`, `remove`, `test`, plus
`client.webhooks.deliveries` — `list`, `iterate`, `stats`, `retry`
`client.credits` — `balance`, `plans`, `history`, `iterate_history`
`client.billing` — `plan`, `usage`
`client.health` — `live`, `ready` (public health checks)

Request parameters and response fields use the API's **camelCase wire format**
and are passed through unchanged — the SDK never re-cases server fields. Immutable
response types live under `CorvoNfse::Types` as `Data` classes whose members
mirror the wire format (e.g. `CorvoNfse::Types::Invoice#accessKey`,
`#competenceDate`).

### Certificate upload

```ruby
p12 = File.binread("certificado.p12")
cert, error = client.certificates.upload("c_1", p12, "senha-do-certificado")
```

### Binary downloads

```ruby
file, error = client.invoices.pdf("inv_1")
File.binwrite("inv_1.pdf", file.content)   # file.mime_type, file.file_name
```

## Webhook signature verification

Verify the `X-Corbo-Signature: sha256=<hex>` header with the raw request body.
Comparison is constant-time.

```ruby
raw   = request.body.read          # do NOT re-serialize the JSON
sig   = request.env["HTTP_X_CORBO_SIGNATURE"]
secret = "whsec_..."               # from webhook creation

if CorvoNfse::Webhooks.verify_signature(raw, sig, secret)
  # authentic
else
  # reject
end
```

## Configuration

```ruby
CorvoNfse::Client.new(
  api_key:  "corvo_live_xxx",        # falls back to ENV["CORVO_API_KEY"]
  base_url: "https://api.corvo.tech",# falls back to ENV["CORVO_BASE_URL"], then the default
  prefix:   "v1",                    # API version prefix (self-hosted installs)
  timeout:  30,                      # open/read/write timeout, seconds
  allow_insecure_http: false         # http:// only allowed for loopback/private hosts
)
```

Auth is the `X-API-Key` header (never `Authorization: Bearer`). `http://` base
URLs are rejected unless the host is loopback/private or you pass
`allow_insecure_http: true`.

## Development

```bash
bundle install
bundle exec rspec          # unit + HMAC known-vector specs (webmock, no network)
bundle exec rake spec
```

The test suite has three layers:

1. **Unit** — transport envelope unwrap, error mapping, and each resource, using
   `webmock` (no real network).
2. **HMAC known vector** — `spec/webhooks_verify_spec.rb` pins the exact
   `sha256=` signature for a known body/secret.
3. **Contract** — `spec/contract/contract_spec.rb` hits a live environment and
   **skips itself** unless `CORVO_API_KEY` and `CORVO_BASE_URL` are set.

## License

MIT — see [LICENSE](LICENSE). © Corvo Technology.
