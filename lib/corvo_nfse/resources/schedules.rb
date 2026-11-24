# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Scheduled and recurring invoices (created by +invoices.create+ with
    # +options.type+ SCHEDULE or RECURRING). Fields are snake_case. The
    # +nextCursor+ of the lists is the offset of the next page: pass it back
    # untouched.
    class Schedules < Base
      MAPPER = ->(item) { Types::Schedule.from_wire(item) }
      RUN_MAPPER = ->(item) { Types::ScheduleRun.from_wire(item) }

      # +status+: active, paused, completed or cancelled.
      def list(status: nil, companyId: nil, limit: nil, cursor: nil)
        @t.list_page("/schedules", query(status, companyId, limit, cursor), mapper: MAPPER)
      end

      def iterate(status: nil, companyId: nil, limit: nil, cursor: nil, &block)
        @t.iterate("/schedules", query(status, companyId, limit, cursor), mapper: MAPPER, &block)
      end

      def get(id)
        @t.request("GET", "/schedules/#{Util.enc(id)}", type: Types::Schedule)
      end

      # Change a schedule; applies to the next runs only. +params+: anchorOn,
      # endsOn, frequency, invoice (fields merged over the stored invoice body).
      def update(id, **params)
        @t.request("PATCH", "/schedules/#{Util.enc(id)}", json: params, type: Types::Schedule)
      end

      def pause(id)
        @t.request("POST", "/schedules/#{Util.enc(id)}/pause", type: Types::Schedule)
      end

      # Resume a paused schedule at its next occurrence.
      def resume(id)
        @t.request("POST", "/schedules/#{Util.enc(id)}/resume", type: Types::Schedule)
      end

      # Cancel a schedule (final).
      def cancel(id)
        @t.request("POST", "/schedules/#{Util.enc(id)}/cancel", type: Types::Schedule)
      end

      # Log of every attempt to run the schedule, newest first.
      def runs(id, limit: nil, cursor: nil)
        @t.list_page(
          "/schedules/#{Util.enc(id)}/runs",
          { limit: limit, cursor: cursor },
          mapper: RUN_MAPPER
        )
      end

      def iterate_runs(id, limit: nil, cursor: nil, &block)
        @t.iterate(
          "/schedules/#{Util.enc(id)}/runs",
          { limit: limit, cursor: cursor },
          mapper: RUN_MAPPER, &block
        )
      end

      private

      def query(status, company_id, limit, cursor)
        { status: status, companyId: company_id, limit: limit, cursor: cursor }
      end
    end
  end
end
