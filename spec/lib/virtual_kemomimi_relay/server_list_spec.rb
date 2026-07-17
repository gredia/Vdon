# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VirtualKemomimiRelay::ServerList do
  describe '.domains' do
    let(:request) { instance_double(Request) }
    let(:response_code) { 200 }
    let(:response_body) { payload.to_json }
    let(:response) { instance_double(HTTP::Response, code: response_code, body_with_limit: response_body) }
    let(:payload) do
      [
        { 'Url' => 'https://dosei.fun', 'Title' => 'どせいすきー', 'Status' => { 'closed' => true } },
        { 'Url' => 'https://virtualkemomimi.net', 'Title' => 'バーチャルケモミミ！', 'Status' => { 'closed' => false, 'relayTimeline' => true } },
        { 'Status' => { 'error' => true }, 'Url' => 'https://misskey.meglia.dev' },
      ]
    end

    before do
      Rails.cache.delete(described_class::CACHE_KEY)
      allow(Request).to receive(:new).with(:get, described_class::URL).and_return(request)
      allow(request).to receive(:add_headers).with('Accept' => 'application/json').and_return(request)
      allow(request).to receive(:perform).and_yield(response)
    end

    it 'extracts domains from relay server entries with Url keys' do
      expect(described_class.domains).to contain_exactly('dosei.fun', 'virtualkemomimi.net', 'misskey.meglia.dev')
    end

    context 'when the relay server responds with a non-success status' do
      let(:response_code) { 503 }

      it 'returns an empty list without caching the failure' do
        expect(described_class.domains).to eq([])
        expect(described_class.domains).to eq([])
        expect(request).to have_received(:perform).twice
      end
    end

    context 'when the relay server returns malformed JSON' do
      let(:response_body) { 'not JSON' }

      it 'returns an empty list' do
        expect(described_class.domains).to eq([])
      end
    end
  end
end
