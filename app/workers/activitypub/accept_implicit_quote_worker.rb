# frozen_string_literal: true

class ActivityPub::AcceptImplicitQuoteWorker
  include Sidekiq::Worker

  BATCH_SIZE = 1_000

  sidekiq_options queue: 'pull', retry: 3, dead: false, lock: :until_executed, lock_ttl: 1.day.to_i

  class << self
    def enqueue_pending(dry_run: false)
      enqueue_scope(Quote.pending.where.not(quoted_status_id: nil), dry_run:)
    end

    def enqueue_for(quoted_status)
      return 0 unless quoted_status.implicit_public_quote_policy?

      enqueue_scope(quoted_status.quotes.pending)
    end

    private

    def enqueue_scope(scope, dry_run: false)
      count = 0

      scope.includes(quoted_status: :account).find_in_batches(batch_size: BATCH_SIZE) do |quotes|
        quote_ids = quotes.filter_map { |quote| quote.id if quote.quoted_status&.implicit_public_quote_policy? }
        count += quote_ids.size

        push_bulk(quote_ids) { |quote_id| [quote_id] } if !dry_run && quote_ids.any?
      end

      count
    end
  end

  def perform(quote_id)
    quote = Quote.find_by(id: quote_id)
    return true if quote.nil?

    accepted = quote.with_lock { quote.accept_implicit_public_quote! }
    return unless accepted

    ::DistributionWorker.perform_async(quote.status_id, { 'update' => true, 'skip_notifications' => true })
  end
end
