# frozen_string_literal: true

class ActivityPub::QuoteRefetchScheduler
  RETRY_DELAY = (30..600)

  class << self
    def schedule_if_missing(quote, quote_uri, **)
      return if quote.quoted_status_id.present?

      schedule(quote, quote_uri, **)
    end

    def schedule(quote, quote_uri, **options)
      return if quote_uri.blank? || quote.deleted?

      ActivityPub::RefetchAndVerifyQuoteWorker.perform_in(rand(RETRY_DELAY).seconds, quote.id, quote_uri, options.stringify_keys)
    end
  end
end
