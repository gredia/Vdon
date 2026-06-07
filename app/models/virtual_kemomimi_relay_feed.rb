# frozen_string_literal: true

class VirtualKemomimiRelayFeed
  def initialize(account, options = {})
    @account = account
    @options = options
  end

  def get(limit, max_id = nil, since_id = nil, min_id = nil)
    scope = public_scope

    scope.merge!(without_replies_scope)
    scope.merge!(without_reblogs_scope)
    scope.merge!(account_filters_scope)
    scope.merge!(media_only_scope) if media_only?
    scope.merge!(language_scope) if account&.chosen_languages.present?
    scope.where!(visibility_scope)

    scope.to_a_paginated_by_id(limit, max_id: max_id, since_id: since_id, min_id: min_id)
  end

  private

  attr_reader :account, :options

  def media_only?
    options[:only_media]
  end

  def include_followed?
    options[:include_followed]
  end

  def public_scope
    Status.public_visibility.joins(:account).merge(Account.without_suspended.without_silenced)
  end

  def without_replies_scope
    Status.without_replies
  end

  def without_reblogs_scope
    Status.without_reblogs
  end

  def media_only_scope
    Status.joins(:media_attachments).group(:id)
  end

  def language_scope
    Status.where(language: account.chosen_languages)
  end

  def account_filters_scope
    Status.not_excluded_by_account(account).merge(Status.not_domain_blocked_by_account(account))
  end

  def visibility_scope
    condition = server_domain_scope.or(local_server_scope).or(own_status_scope)
    condition = condition.or(followed_status_scope) if include_followed?
    condition
  end

  def server_domain_scope
    Account.arel_table[:domain].in(VirtualKemomimiRelay::ServerList.domains)
  end

  def local_server_scope
    Account.arel_table[:domain].eq(nil)
  end

  def own_status_scope
    Status.arel_table[:account_id].eq(account.id)
  end

  def followed_status_scope
    Status.arel_table[:account_id].in(account.following.select(:id).arel)
  end
end
