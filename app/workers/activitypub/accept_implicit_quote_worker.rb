# frozen_string_literal: true

class ActivityPub::AcceptImplicitQuoteWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 3, dead: false, lock: :until_executed, lock_ttl: 1.day.to_i

  def perform(quote_id)
    quote = Quote.find_by(id: quote_id)
    return true if quote.nil?

    accepted = quote.with_lock { quote.accept_implicit_public_quote! }
    return unless accepted

    ::DistributionWorker.perform_async(quote.status_id, { 'update' => true, 'skip_notifications' => true })
  end
end
