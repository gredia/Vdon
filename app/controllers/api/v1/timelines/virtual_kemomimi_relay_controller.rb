# frozen_string_literal: true

class Api::V1::Timelines::VirtualKemomimiRelayController < Api::V1::Timelines::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:statuses' }
  before_action :require_user!

  PERMITTED_PARAMS = %i(limit only_media social with_reblogs with_replies with_quotes).freeze

  def show
    @statuses = load_statuses
    render json: @statuses, each_serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(@statuses, current_user.account_id)
  end

  private

  def load_statuses
    preload_collection(virtual_kemomimi_relay_statuses, Status)
  end

  def virtual_kemomimi_relay_statuses
    virtual_kemomimi_relay_feed.get(
      limit_param(DEFAULT_STATUSES_LIMIT),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )
  end

  def virtual_kemomimi_relay_feed
    VirtualKemomimiRelayFeed.new(
      current_account,
      only_media: truthy_param?(:only_media),
      include_followed: truthy_param?(:social),
      with_reblogs: truthy_param_with_default?(:with_reblogs),
      with_replies: truthy_param_with_default?(:with_replies),
      with_quotes: truthy_param_with_default?(:with_quotes)
    )
  end

  def truthy_param_with_default?(key)
    params.key?(key) ? truthy_param?(key) : true
  end

  def next_path
    api_v1_timelines_virtual_kemomimi_relay_url next_path_params
  end

  def prev_path
    api_v1_timelines_virtual_kemomimi_relay_url prev_path_params
  end
end
