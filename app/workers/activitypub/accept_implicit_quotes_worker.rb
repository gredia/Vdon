# frozen_string_literal: true

class ActivityPub::AcceptImplicitQuotesWorker
  include Sidekiq::Worker

  BATCH_SIZE = 1_000

  sidekiq_options queue: 'pull', retry: 3, dead: false, lock: :until_executed, lock_ttl: 1.day.to_i

  def perform(quoted_status_id)
    quoted_status = Status.find_by(id: quoted_status_id)
    return true if quoted_status.nil?
    return unless quoted_status.implicit_public_quote_policy?

    quoted_status.quotes.pending.in_batches(of: BATCH_SIZE) do |quotes|
      ActivityPub::AcceptImplicitQuoteWorker.push_bulk(quotes.pluck(:id)) { |quote_id| [quote_id] }
    end
  end
end
