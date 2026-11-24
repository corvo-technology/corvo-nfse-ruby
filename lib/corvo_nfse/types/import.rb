# frozen_string_literal: true

module CorvoNfse
  module Types
    # Counters of an import (snake_case wire).
    ImportCounters = define_data(
      :total, :valid, :invalid, :pending, :accepted, :authorized, :failed,
      :valid_amount, :pending_amount, :authorized_amount, :failed_amount,
      :awaiting_amount, :awaiting_credits
    )

    # An import of a CSV/Excel spreadsheet (snake_case wire). +status+:
    # processing, ready, emitting, done or failed.
    ImportJob = define_data(
      :id, :company_id, :file_name, :status, :rows_expected, :unknown_columns,
      :counters, :error_code, :emit_started_at, :emit_finished_at, :created_at
    ) do
      nested counters: ImportCounters
    end

    # Answer of +imports.start+: +duplicate_of+ is the id of an earlier import
    # of the same file, or nil.
    ImportStart = define_data(:id, :status, :duplicate_of)

    # One row of an import. +data+ is the raw row; +status+: valid, invalid,
    # queued, accepted or rejected.
    ImportRow = define_data(
      :line, :status, :data, :error_code, :error_message, :invoice_id
    )
  end
end
