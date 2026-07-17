# frozen_string_literal: true

class ActivityPub::RefetchAndVerifyQuoteWorker
  include Sidekiq::Worker
  include ExponentialBackoff
  include JsonLdHelper

  sidekiq_options queue: 'pull', retry: 5

  class MissingQuotedStatusError < StandardError; end

  def perform(quote_id, quoted_uri, options = {})
    quote = Quote.find(quote_id)
    ActivityPub::VerifyQuoteService.new.call(quote, options['approval_uri'], fetchable_quoted_uri: quoted_uri, request_id: options['request_id'])
    state_changed = quote.state_previously_changed?
    quote.reload
    raise MissingQuotedStatusError, "Quoted status #{quoted_uri.inspect} is still unavailable for quote #{quote.id}" if quoted_uri.present? && quote.pending? && quote.quoted_status_id.blank?

    ::DistributionWorker.perform_async(quote.status_id, { 'update' => true }) if state_changed
  rescue ActiveRecord::RecordNotFound
    # Do nothing
    true
  rescue Mastodon::UnexpectedResponseError => e
    raise e unless response_error_unsalvageable?(e.response)
  end
end
