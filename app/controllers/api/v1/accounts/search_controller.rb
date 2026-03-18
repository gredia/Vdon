# frozen_string_literal: true

class Api::V1::Accounts::SearchController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:accounts' }
  before_action :require_user!

  def show
    @accounts = account_search
    render json: @accounts, each_serializer: REST::AccountSerializer
  end

  private

  def account_search
    if requires_primary_db?(params[:q])
      perform_account_search
    else
      with_read_replica { perform_account_search }
    end
  end

  def perform_account_search
    AccountSearchService.new.call(
      params[:q],
      current_account,
      limit: limit_param(DEFAULT_ACCOUNTS_LIMIT),
      resolve: truthy_param?(:resolve),
      following: truthy_param?(:following),
      offset: params[:offset]
    )
  end

  def requires_primary_db?(query)
    return false unless truthy_param?(:resolve)
    return false if query.blank?

    q = query.strip

    return true if q.match?(%r{\Ahttps?://})

    q_without_at = q.gsub(/\A@/, '')
    return true if q_without_at.include?('@') && "@#{q_without_at}".match?(/\A#{Account::MENTION_RE}\z/i)

    false
  end
end
