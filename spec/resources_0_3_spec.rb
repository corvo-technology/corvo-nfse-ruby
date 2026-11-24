# frozen_string_literal: true

# Behavior of the resources added in 0.3.0: parsing, pagination, errors, binary
# and multipart. Method/path/query/body against the contract are checked
# for every operation in spec/contract/operations_spec.rb.
RSpec.describe "resources added in API contract 0.3.0" do
  let(:client) { build_client }
  let(:page_info) { { limit: 2, hasMore: false, nextCursor: nil } }

  def body_of(data, extra = {})
    { data: data }.merge(extra).to_json
  end

  describe "invoices.create" do
    it "returns an Invoice for an immediate emission" do
      stub_request(:post, "#{BASE_URL}/v1/invoices")
        .to_return(status: 202, body: body_of({ id: "inv_1", status: "queued", documentsStatus: "pending", stage: "pending" }), headers: json_headers)
      data, error = client.invoices.create({ amount: 10 }, idempotency_key: "k1")
      expect(error).to be_nil
      expect(data).to be_a(CorvoNfse::Types::Invoice)
      expect(data.status).to eq("queued")
      expect(data.documentsStatus).to eq("pending")
    end

    it "returns a Schedule (snake_case) for SCHEDULE and RECURRING" do
      schedule = { id: "sch_1", company_id: "c_1", kind: "recurring", status: "active", anchor_on: "2026-12-01",
                   frequency: "MONTHLY", ends_on: nil, next_run_on: "2026-12-01", attempts: 0, invoice: { amount: 10 } }
      stub_request(:post, "#{BASE_URL}/v1/invoices")
        .to_return(status: 202, body: body_of(schedule), headers: json_headers)
      data, error = client.invoices.create({ amount: 10, options: { type: "RECURRING", recurrence: { frequency: "MONTHLY" } } })
      expect(error).to be_nil
      expect(data).to be_a(CorvoNfse::Types::Schedule)
      expect(data.kind).to eq("recurring")
      expect(data.next_run_on).to eq("2026-12-01")
      expect(data.invoice).to eq({ "amount" => 10 })
    end
  end

  describe "invoices extras" do
    it "substitute sends the Idempotency-Key and returns the new Invoice" do
      stub_request(:post, "#{BASE_URL}/v1/invoices/inv_1/substitute")
        .to_return(status: 202, body: body_of({ id: "inv_2", status: "queued", substitutesInvoiceId: "inv_1", substitutionDescription: "motivo" }), headers: json_headers)
      data, error = client.invoices.substitute("inv_1", { description: "motivo" }, idempotency_key: "sub-1")
      expect(error).to be_nil
      expect(data.substitutesInvoiceId).to eq("inv_1")
      expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices/inv_1/substitute")
        .with(headers: { "Idempotency-Key" => "sub-1" }, body: { "description" => "motivo" })
    end

    it "send_email sends the optional destination and no body when omitted" do
      stub_request(:post, "#{BASE_URL}/v1/invoices/inv_1/email")
        .to_return(status: 202, body: body_of({ emailId: "em_1", status: "queued" }), headers: json_headers)
      client.invoices.send_email("inv_1", email: "outro@exemplo.com", idempotency_key: "e1")
      expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices/inv_1/email")
        .with(headers: { "Idempotency-Key" => "e1" }, body: { "email" => "outro@exemplo.com" })
      WebMock.reset_executed_requests!
      client.invoices.send_email("inv_1")
      expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices/inv_1/email").with(body: nil)
    end

    it "list filters by customerTaxId" do
      stub_request(:get, "#{BASE_URL}/v1/invoices").with(query: { "customerTaxId" => "11222333000181" })
                                                    .to_return(status: 200, body: { data: [{ id: "inv_1" }], pagination: page_info }.to_json, headers: json_headers)
      page, error = client.invoices.list(customerTaxId: "11222333000181")
      expect(error).to be_nil
      expect(page.data.first.id).to eq("inv_1")
    end

    it "overview types the recent invoices and review sends invoiceIds" do
      overview = { period: "7d", from: "2026-11-17", to: "2026-11-24", timezone: "America/Sao_Paulo",
                   counts: { authorized: 3, processing: 1, rejected: 0 }, dailyActivity: [{ date: "2026-11-24", count: 4 }],
                   recentInvoices: [{ id: "inv_1", status: "authorized" }] }
      stub_request(:get, "#{BASE_URL}/v1/invoices/overview").to_return(status: 200, body: body_of(overview), headers: json_headers)
      stub_request(:post, "#{BASE_URL}/v1/invoices/review")
        .to_return(status: 202, body: body_of({ results: [{ id: "inv_1", outcome: "retried" }] }), headers: json_headers)

      data, error = client.invoices.overview
      expect(error).to be_nil
      expect(data.counts["authorized"]).to eq(3)
      expect(data.recentInvoices.first).to be_a(CorvoNfse::Types::Invoice)

      review, rerr = client.invoices.review(invoice_ids: ["inv_1"], action: "discard")
      expect(rerr).to be_nil
      expect(review.results.first["outcome"]).to eq("retried")
      expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices/review").with(body: { "invoiceIds" => ["inv_1"], "action" => "discard" })
    end

    it "lists the ten invoice statuses of the contract" do
      expect(CorvoNfse::Types::INVOICE_STATUSES.length).to eq(10)
    end
  end

  describe "customers and cnpj" do
    it "search paginates with the opaque cursor and iterate walks every page" do
      stub_request(:get, "#{BASE_URL}/v1/customers").with(query: { "search" => "acme", "limit" => "1" })
                                                    .to_return(status: 200, body: { data: [{ taxId: "1", name: "Acme" }], pagination: { limit: 1, hasMore: true, nextCursor: "1" } }.to_json, headers: json_headers)
      stub_request(:get, "#{BASE_URL}/v1/customers").with(query: { "search" => "acme", "limit" => "1", "cursor" => "1" })
                                                    .to_return(status: 200, body: { data: [{ taxId: "2", name: "Acme 2" }], pagination: { limit: 1, hasMore: false, nextCursor: nil } }.to_json, headers: json_headers)
      page, error = client.customers.search(search: "acme", limit: 1)
      expect(error).to be_nil
      expect(page.data.first).to be_a(CorvoNfse::Types::SavedCustomer)
      expect(page.pagination.nextCursor).to eq("1")
      expect(client.customers.iterate(search: "acme", limit: 1).map(&:taxId)).to eq(%w[1 2])
    end

    it "get, update (null email) and remove" do
      stub_request(:get, "#{BASE_URL}/v1/customers/11222333000181")
        .to_return(status: 200, body: body_of({ taxId: "11222333000181", name: "Acme", email: nil }), headers: json_headers)
      stub_request(:patch, "#{BASE_URL}/v1/customers/11222333000181")
        .to_return(status: 200, body: body_of({ taxId: "11222333000181", name: "Acme SA", email: nil }), headers: json_headers)
      stub_request(:delete, "#{BASE_URL}/v1/customers/11222333000181")
        .to_return(status: 200, body: body_of(nil), headers: json_headers)
      customer, = client.customers.get("11222333000181")
      expect(customer.name).to eq("Acme")
      updated, error = client.customers.update("11222333000181", name: "Acme SA", email: nil)
      expect(error).to be_nil
      expect(updated.name).to eq("Acme SA")
      expect(WebMock).to have_requested(:patch, "#{BASE_URL}/v1/customers/11222333000181").with(body: { "name" => "Acme SA", "email" => nil })
      _, rerr = client.customers.remove("11222333000181")
      expect(rerr).to be_nil
    end

    it "cnpj lookup types the profile and its address; CNPJ_INVALID is the error code" do
      stub_request(:get, "#{BASE_URL}/v1/cnpj/11222333000181")
        .to_return(status: 200, body: body_of({ legalName: "ACME LTDA", tradeName: "Acme", active: true, situation: "ATIVA", mei: false, simples: true,
                                                 municipalityCode: "3550308", address: { street: "Rua A", number: "1", district: "Centro", city: "Sao Paulo", state: "SP", zip: "01000000" } }), headers: json_headers)
      stub_request(:get, "#{BASE_URL}/v1/cnpj/123")
        .to_return(status: 400, body: { statusCode: 400, code: "CNPJ_INVALID", message: "invalid" }.to_json, headers: json_headers)
      data, error = client.cnpj.lookup("11222333000181")
      expect(error).to be_nil
      expect(data.address).to be_a(CorvoNfse::Types::PostalAddress)
      expect(data.address.city).to eq("Sao Paulo")
      expect(data.simples).to be(true)
      _, err = client.cnpj.lookup("123")
      expect(err.code).to eq("CNPJ_INVALID")
    end
  end

  describe "service favorites, accountant package and invoice package" do
    it "favorites list/create/remove" do
      fav = { id: "f_1", companyId: "c_1", label: "Consultoria", description: "x", serviceCode: "01.01", amountCents: nil }
      stub_request(:get, "#{BASE_URL}/v1/companies/c_1/service-favorites").to_return(status: 200, body: body_of([fav]), headers: json_headers)
      stub_request(:post, "#{BASE_URL}/v1/companies/c_1/service-favorites").to_return(status: 201, body: body_of(fav), headers: json_headers)
      stub_request(:delete, "#{BASE_URL}/v1/companies/c_1/service-favorites/f_1").to_return(status: 200, body: body_of({ deleted: true }), headers: json_headers)
      list, error = client.service_favorites.list("c_1")
      expect(error).to be_nil
      expect(list.first).to be_a(CorvoNfse::Types::ServiceFavorite)
      created, = client.service_favorites.create("c_1", label: "Consultoria", description: "x", serviceCode: "01.01")
      expect(created.id).to eq("f_1")
      deleted, = client.service_favorites.remove("c_1", "f_1")
      expect(deleted).to eq({ "deleted" => true })
    end

    it "accountant package get/update/send/list_sends" do
      base = "#{BASE_URL}/v1/companies/c_1/accountant-package"
      stub_request(:get, base).to_return(status: 200, body: body_of({ email: "a@b.co", lastSentMonth: "2026-10" }), headers: json_headers)
      stub_request(:put, base).to_return(status: 200, body: body_of({ email: nil, lastSentMonth: nil, testEmailSent: false }), headers: json_headers)
      stub_request(:post, "#{base}/send").to_return(status: 200, body: body_of({ status: "sent" }), headers: json_headers)
      stub_request(:get, "#{base}/sends").to_return(status: 200, body: body_of([{ id: "s1", month: "2026-10", status: "sent", trigger: "manual", invoiceCount: 3, totalCents: 1000 }]), headers: json_headers)

      expect(client.accountant_package.get("c_1").first.email).to eq("a@b.co")
      upd, = client.accountant_package.update("c_1", nil)
      expect(upd.testEmailSent).to be(false)
      expect(WebMock).to have_requested(:put, base).with(body: { "accountantEmail" => nil })
      sent, = client.accountant_package.send_package("c_1", month: "2026-10")
      expect(sent.status).to eq("sent")
      sends, = client.accountant_package.list_sends("c_1")
      expect(sends.first).to be_a(CorvoNfse::Types::AccountantSend)
    end

    it "invoice package summary and ZIP download (bytes)" do
      stub_request(:get, "#{BASE_URL}/v1/companies/c_1/invoice-package/summary").with(query: { "month" => "2026-10" })
                                                                                .to_return(status: 200, body: body_of({ companyName: "Acme", companyTaxId: "1", month: "2026-10", count: 3, total: 300.5, limit: 500 }), headers: json_headers)
      zip = "PK\x03\x04\xFF\x00".b
      stub_request(:get, "#{BASE_URL}/v1/companies/c_1/invoice-package").with(query: { "month" => "2026-10", "include" => "xml" })
                                                                         .to_return(status: 200, body: zip, headers: { "Content-Type" => "application/zip", "Content-Disposition" => 'attachment; filename="pacote-2026-10.zip"' })
      summary, = client.invoice_package.summary("c_1", month: "2026-10")
      expect(summary.count).to eq(3)
      file, error = client.invoice_package.download("c_1", month: "2026-10", include: "xml")
      expect(error).to be_nil
      expect(file.content.bytes).to eq(zip.bytes)
      expect(file.mime_type).to eq("application/zip")
      expect(file.file_name).to eq("pacote-2026-10.zip")
    end
  end

  describe "schedules" do
    let(:schedule) { { id: "sch_1", company_id: "c_1", kind: "once", status: "active", anchor_on: "2026-12-01", attempts: 0, invoice: {} } }

    it "list passes the offset cursor back untouched" do
      stub_request(:get, "#{BASE_URL}/v1/schedules").with(query: { "status" => "active", "limit" => "1" })
                                                    .to_return(status: 200, body: { data: [schedule], pagination: { limit: 1, hasMore: true, nextCursor: "1" } }.to_json, headers: json_headers)
      stub_request(:get, "#{BASE_URL}/v1/schedules").with(query: { "status" => "active", "limit" => "1", "cursor" => "1" })
                                                    .to_return(status: 200, body: { data: [schedule.merge(id: "sch_2")], pagination: page_info }.to_json, headers: json_headers)
      expect(client.schedules.iterate(status: "active", limit: 1).map(&:id)).to eq(%w[sch_1 sch_2])
    end

    it "get/update/pause/resume/cancel return a Schedule and runs lists attempts" do
      %w[pause resume cancel].each do |action|
        stub_request(:post, "#{BASE_URL}/v1/schedules/sch_1/#{action}").to_return(status: 200, body: body_of(schedule.merge(status: action)), headers: json_headers)
      end
      stub_request(:patch, "#{BASE_URL}/v1/schedules/sch_1").to_return(status: 200, body: body_of(schedule), headers: json_headers)
      stub_request(:get, "#{BASE_URL}/v1/schedules/sch_1/runs")
        .to_return(status: 200, body: { data: [{ id: "r1", occurrence_on: "2026-12-01", ran_on: "2026-12-01", attempt: 1, outcome: "failed", error_code: "E0014" }], pagination: page_info }.to_json, headers: json_headers)

      expect(client.schedules.pause("sch_1").first).to be_a(CorvoNfse::Types::Schedule)
      expect(client.schedules.resume("sch_1").first.status).to eq("resume")
      expect(client.schedules.cancel("sch_1").first.status).to eq("cancel")
      expect(client.schedules.update("sch_1", anchorOn: "2026-12-02").first.id).to eq("sch_1")
      runs, error = client.schedules.runs("sch_1")
      expect(error).to be_nil
      expect(runs.data.first).to be_a(CorvoNfse::Types::ScheduleRun)
      expect(runs.data.first.error_code).to eq("E0014")
    end

    it "maps ERROR_SCHEDULE_NOT_FOUND" do
      stub_request(:get, "#{BASE_URL}/v1/schedules/nope")
        .to_return(status: 404, body: { statusCode: 404, code: "ERROR_SCHEDULE_NOT_FOUND", message: "x" }.to_json, headers: json_headers)
      _, error = client.schedules.get("nope")
      expect(error.code).to eq("ERROR_SCHEDULE_NOT_FOUND")
    end
  end

  describe "imports" do
    let(:job) do
      { id: "imp_1", company_id: "c_1", file_name: "notas.csv", status: "ready", rows_expected: 2, unknown_columns: [],
        counters: { total: 2, valid: 2, invalid: 0, pending: 0, accepted: 0, authorized: 0, failed: 0, valid_amount: 20.5,
                    pending_amount: 0, authorized_amount: 0, failed_amount: 0, awaiting_amount: 0, awaiting_credits: 0 },
        created_at: "2026-11-24T10:00:00Z" }
    end

    it "start uploads a multipart form with a binary file and the company" do
      stub_request(:post, "#{BASE_URL}/v1/imports").to_return(status: 202, body: body_of({ id: "imp_1", status: "processing", duplicate_of: nil }), headers: json_headers)
      xlsx = "PK\x03\x04\xC3\x28\xFF".b
      data, error = client.imports.start(xlsx, file_name: "notas.xlsx", company_id: "c_1")
      expect(error).to be_nil
      expect(data).to be_a(CorvoNfse::Types::ImportStart)
      expect(data.status).to eq("processing")
      expect(WebMock).to(have_requested(:post, "#{BASE_URL}/v1/imports").with { |req|
        req.headers["Content-Type"].start_with?("multipart/form-data; boundary=") &&
          req.body.b.include?(xlsx) &&
          req.body.include?('name="file"; filename="notas.xlsx"') &&
          req.body.include?("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") &&
          req.body.include?('name="companyId"')
      })
    end

    it "get types the job and its counters; list returns the recent jobs" do
      stub_request(:get, "#{BASE_URL}/v1/imports/imp_1").to_return(status: 200, body: body_of(job), headers: json_headers)
      stub_request(:get, "#{BASE_URL}/v1/imports").to_return(status: 200, body: body_of([job]), headers: json_headers)
      data, error = client.imports.get("imp_1")
      expect(error).to be_nil
      expect(data.counters).to be_a(CorvoNfse::Types::ImportCounters)
      expect(data.counters.valid_amount).to eq(20.5)
      jobs, = client.imports.list
      expect(jobs.first.id).to eq("imp_1")
    end

    it "emit, rows, update_row, discard and the CSV downloads" do
      stub_request(:post, "#{BASE_URL}/v1/imports/imp_1/emit").to_return(status: 202, body: body_of(job.merge(status: "emitting")), headers: json_headers)
      stub_request(:get, "#{BASE_URL}/v1/imports/imp_1/rows").with(query: { "status" => "invalid" })
                                                             .to_return(status: 200, body: { data: [{ line: 3, status: "invalid", data: { cnpj: "x" }, error_code: "ERROR_IMPORT_ROW", error_message: "bad" }], pagination: page_info }.to_json, headers: json_headers)
      stub_request(:patch, "#{BASE_URL}/v1/imports/imp_1/rows/3").to_return(status: 200, body: body_of({ line: 3, status: "valid", data: {} }), headers: json_headers)
      stub_request(:delete, "#{BASE_URL}/v1/imports/imp_1").to_return(status: 204)
      stub_request(:get, "#{BASE_URL}/v1/imports/template").to_return(status: 200, body: "cnpj;valor\n", headers: { "Content-Type" => "text/csv", "Content-Disposition" => 'attachment; filename="modelo.csv"' })
      stub_request(:get, "#{BASE_URL}/v1/imports/imp_1/errors.csv").to_return(status: 200, body: "linha;erro\n", headers: { "Content-Type" => "text/csv" })

      emitted, = client.imports.emit("imp_1", send_email: false)
      expect(emitted.status).to eq("emitting")
      expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/imports/imp_1/emit").with(body: { "sendEmail" => false })
      rows, = client.imports.rows("imp_1", status: "invalid")
      expect(rows.data.first).to be_a(CorvoNfse::Types::ImportRow)
      expect(rows.data.first.error_code).to eq("ERROR_IMPORT_ROW")
      row, = client.imports.update_row("imp_1", 3, { amount: 10 })
      expect(row.status).to eq("valid")
      expect(WebMock).to have_requested(:patch, "#{BASE_URL}/v1/imports/imp_1/rows/3").with(body: { "item" => { "amount" => 10 } })
      discarded, derr = client.imports.discard("imp_1")
      expect([discarded, derr]).to eq([nil, nil])
      template, = client.imports.download_template
      expect(template.content).to eq("cnpj;valor\n")
      expect(template.file_name).to eq("modelo.csv")
      errors, = client.imports.download_errors("imp_1")
      expect(errors.mime_type).to eq("text/csv")
    end
  end

  describe "company configuration" do
    it "dps sequence get/set and DPS_NUMBER_BELOW_CURRENT" do
      stub_request(:get, "#{BASE_URL}/v1/companies/c_1/dps-sequence").to_return(status: 200, body: body_of({ series: "1", lastNumber: 10 }), headers: json_headers)
      stub_request(:put, "#{BASE_URL}/v1/companies/c_1/dps-sequence").with(body: { "lastNumber" => 5 })
                                                                      .to_return(status: 409, body: { statusCode: 409, code: "DPS_NUMBER_BELOW_CURRENT", message: "below" }.to_json, headers: json_headers)
      seq, = client.dps_sequence.get("c_1")
      expect(seq.lastNumber).to eq(10)
      _, error = client.dps_sequence.set("c_1", last_number: 5)
      expect(error.code).to eq("DPS_NUMBER_BELOW_CURRENT")
    end

    it "fiscal profiles and service tax profiles are typed" do
      stub_request(:get, "#{BASE_URL}/v1/companies/c_1/fiscal-profile").to_return(status: 200, body: body_of([{ id: "fp_1", taxRegime: "MEI", reviewStatus: "approved" }]), headers: json_headers)
      stub_request(:post, "#{BASE_URL}/v1/companies/c_1/service-tax-profiles/s_1/approve").to_return(status: 201, body: body_of({ id: "s_1", reviewStatus: "approved", withholdingRates: { irrf: "1.5" } }), headers: json_headers)
      stub_request(:delete, "#{BASE_URL}/v1/companies/c_1/service-tax-profiles/s_1").to_return(status: 200, body: body_of(nil), headers: json_headers)
      profiles, = client.fiscal_profiles.list("c_1")
      expect(profiles.first).to be_a(CorvoNfse::Types::FiscalProfile)
      approved, = client.service_tax_profiles.approve("c_1", "s_1")
      expect(approved.withholdingRates["irrf"]).to eq("1.5")
      _, error = client.service_tax_profiles.remove("c_1", "s_1")
      expect(error).to be_nil
    end

    it "company exposes municipalityAgreement as a typed object" do
      stub_request(:get, "#{BASE_URL}/v1/companies/c_1")
        .to_return(status: 200, body: body_of({ id: "c_1", municipalityAgreement: { status: "active", agreementType: "x", checkedAt: "2026-11-01" } }), headers: json_headers)
      company, = client.companies.get("c_1")
      expect(company.municipalityAgreement).to be_a(CorvoNfse::Types::MunicipalityAgreement)
      expect(company.municipalityAgreement.status).to eq("active")
    end

    it "fiscal portal status" do
      stub_request(:get, "#{BASE_URL}/v1/fiscal-portal/status").to_return(status: 200, body: body_of({ available: false, environment: "test", retryAt: "2026-11-24T12:00:00Z" }), headers: json_headers)
      status, = client.fiscal_portal.status
      expect(status.available).to be(false)
    end
  end

  describe "integrations" do
    let(:connection) { { id: "n_1", companyId: "c_1", provider: "stripe", environment: "test", state: "draft", webhookUrl: "https://api.corvo.tech/x", createdAt: "2026-11-24" } }

    it "providers list and connection create returns the secrets once" do
      stub_request(:get, "#{BASE_URL}/v1/integrations/providers").to_return(status: 200, body: body_of([{ id: "stripe", name: "Stripe", version: "1", supportedFlows: ["charge"], credentialFields: [], webhookInstructions: { en: "a", pt: "b" } }]), headers: json_headers)
      stub_request(:post, "#{BASE_URL}/v1/integrations/connections").to_return(status: 201, body: body_of(connection.merge(secrets: { webhookSecret: "whsec" })), headers: json_headers)
      providers, = client.integrations.list_providers
      expect(providers.first.webhookInstructions["pt"]).to eq("b")
      created, error = client.integration_connections.create(companyId: "c_1", provider: "stripe", credentials: { apiKey: "k" })
      expect(error).to be_nil
      expect(created).to be_a(CorvoNfse::Types::IntegrationConnectionCreated)
      expect(created.secrets["webhookSecret"]).to eq("whsec")
    end

    it "lifecycle, rules, events and operations" do
      %w[validate activate pause disconnect].each do |action|
        stub_request(:post, "#{BASE_URL}/v1/integrations/connections/n_1/#{action}").to_return(status: 200, body: body_of(connection.merge(state: action)), headers: json_headers)
      end
      stub_request(:put, "#{BASE_URL}/v1/integrations/connections/n_1/rules").to_return(status: 200, body: body_of([{ id: "r_1", sendEmail: true, service: { code: "01.01" } }]), headers: json_headers)
      stub_request(:get, "#{BASE_URL}/v1/integrations/connections/n_1/events").to_return(status: 200, body: body_of([{ id: "e_1", state: "processed", attempts: 1 }]), headers: json_headers)
      stub_request(:get, "#{BASE_URL}/v1/integrations/connections/n_1/operations").to_return(status: 200, body: body_of([{ id: "o_1", fiscalStatus: "blocked", blockReason: "customer", customer: nil }]), headers: json_headers)
      stub_request(:patch, "#{BASE_URL}/v1/integrations/operations/o_1/customer").to_return(status: 200, body: body_of({ id: "o_1", fiscalStatus: "submitted" }), headers: json_headers)
      stub_request(:post, "#{BASE_URL}/v1/integrations/operations/o_1/retry").to_return(status: 200, body: body_of({ operationId: "o_1", state: "processed" }), headers: json_headers)

      expect(client.integration_connections.activate("n_1").first.state).to eq("activate")
      expect(client.integration_connections.validate("n_1").first).to be_a(CorvoNfse::Types::IntegrationConnection)
      rules, = client.integration_connections.replace_rules("n_1", [{ sendEmail: true, service: { code: "01.01" } }])
      expect(rules.first).to be_a(CorvoNfse::Types::IntegrationRule)
      expect(WebMock).to have_requested(:put, "#{BASE_URL}/v1/integrations/connections/n_1/rules").with(body: { "rules" => [{ "sendEmail" => true, "service" => { "code" => "01.01" } }] })
      expect(client.integration_connections.list_events("n_1").first.first.state).to eq("processed")
      expect(client.integration_connections.list_operations("n_1").first.first.blockReason).to eq("customer")
      expect(client.integration_operations.complete_customer("o_1", taxId: "1").first.fiscalStatus).to eq("submitted")
      expect(client.integration_operations.retry("o_1").first.state).to eq("processed")
    end
  end

  describe "transport" do
    it "sends the SDK User-Agent and x-api-key on every request" do
      stub_request(:get, "#{BASE_URL}/v1/credits").to_return(status: 200, body: body_of({ balance: 1 }), headers: json_headers)
      client.credits.balance
      expect(WebMock).to have_requested(:get, "#{BASE_URL}/v1/credits")
        .with(headers: { "User-Agent" => "corvo-nfse-ruby/0.3.0", "X-Api-Key" => API_KEY })
    end

    it "keeps the error code, Retry-After and requestId of a 429" do
      stub_request(:get, "#{BASE_URL}/v1/customers")
        .to_return(status: 429, body: { statusCode: 429, code: "ERROR_RATE_LIMIT", message: "slow down", requestId: "req_9" }.to_json,
                   headers: json_headers("Retry-After" => "7"))
      _, error = client.customers.search
      expect(error.status).to eq(429)
      expect(error.code).to eq("ERROR_RATE_LIMIT")
      expect(error.retry_after).to eq(7)
      expect(error.request_id).to eq("req_9")
    end
  end
end
