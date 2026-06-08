# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Web app routes' do
  it 'routes virtual kemomimi relay timeline to the React app' do
    expect(get('/virtual-kemomimi-relay'))
      .to route_to('home#index')
  end

  it 'routes virtual kemomimi relay social timeline to the React app' do
    expect(get('/virtual-kemomimi-relay/social'))
      .to route_to('home#index', any: 'social')
  end
end
