# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Virtual kemomimi relay timeline' do
  let(:user) { Fabricate(:user) }
  let(:scopes) { 'read:statuses' }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'GET /api/v1/timelines/virtual_kemomimi_relay' do
    subject do
      get '/api/v1/timelines/virtual_kemomimi_relay', headers: headers, params: params
    end

    let(:params) { {} }
    let!(:relay_status) { Fabricate(:status, account: Fabricate(:account, domain: 'relay.example')) }
    let!(:local_status) { Fabricate(:status) }
    let!(:unlisted_status) { Fabricate(:status, account: Fabricate(:account, domain: 'unlisted.example')) }

    before do
      allow(VirtualKemomimiRelay::ServerList).to receive(:domains).and_return(['relay.example'])
    end

    it_behaves_like 'forbidden for wrong scope', 'profile'

    it 'returns public statuses from local and relay-listed accounts', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(response.content_type).to start_with('application/json')
      expect(response.parsed_body.pluck(:id)).to contain_exactly(local_status.id.to_s, relay_status.id.to_s)
      expect(response.parsed_body.pluck(:id)).to_not include(unlisted_status.id.to_s)
    end

    context 'with the social option' do
      let(:params) { { social: true } }
      let!(:followed_status) { Fabricate(:status, account: Fabricate(:account, domain: 'followed.example')) }

      before do
        user.account.follow!(followed_status.account)
      end

      it 'also returns public statuses from followed accounts' do
        subject

        expect(response.parsed_body.pluck(:id)).to include(followed_status.id.to_s)
      end
    end

    context 'without an authorization header' do
      let(:headers) { {} }

      it 'returns http unauthorized' do
        subject

        expect(response).to have_http_status(401)
      end
    end

    context 'without a user context' do
      let(:token) { Fabricate(:accessible_access_token, resource_owner_id: nil, scopes: scopes) }

      it 'returns http unprocessable entity' do
        subject

        expect(response).to have_http_status(422)
      end
    end
  end
end
