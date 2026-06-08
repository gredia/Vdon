# frozen_string_literal: true

class ActivityPub::RefetchAndVerifyQuoteWorker
  include Sidekiq::Worker
  include ExponentialBackoff
  include JsonLdHelper

  class MissingQuotedStatusError < StandardError; end

  sidekiq_options queue: 'pull', retry: 5

  def perform(quote_id, quoted_uri, options = {})
    quote = Quote.find(quote_id)
    ActivityPub::VerifyQuoteService.new.call(quote, options['approval_uri'], fetchable_quoted_uri: quoted_uri, request_id: options['request_id'], allow_legacy_quote_approval: options['allow_legacy_quote_approval'] == true)
    state_changed = quote.state_previously_changed?
    quote.reload
    raise MissingQuotedStatusError if quote_missing_quoted_status?(quote, quoted_uri)

    ::DistributionWorker.perform_async(quote.status_id, { 'update' => true }) if state_changed
  rescue ActiveRecord::RecordNotFound
    # Do nothing
    true
  rescue Mastodon::UnexpectedResponseError => e
    raise e unless response_error_unsalvageable?(e.response)
  end

  private

  def quote_missing_quoted_status?(quote, quoted_uri)
    quoted_uri.present? && quote.pending? && quote.quoted_status_id.blank?
  end
end
