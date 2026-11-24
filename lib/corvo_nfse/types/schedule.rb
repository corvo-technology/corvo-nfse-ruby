# frozen_string_literal: true

module CorvoNfse
  module Types
    # A scheduled (+kind+ "once") or recurring invoice. The wire is snake_case
    # and kept as it is. +invoice+ is the raw invoice body each run issues.
    Schedule = define_data(
      :id, :company_id, :kind, :status, :anchor_on, :frequency, :ends_on,
      :next_run_on, :last_run_on, :attempts, :pause_reason, :invoice, :created_at
    )

    # One attempt to run a schedule (snake_case wire). +outcome+: issued or failed.
    ScheduleRun = define_data(
      :id, :occurrence_on, :ran_on, :attempt, :outcome, :invoice_id,
      :error_code, :error_message, :created_at
    )
  end
end
