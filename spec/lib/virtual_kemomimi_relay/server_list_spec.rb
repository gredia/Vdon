# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VirtualKemomimiRelay::ServerList do
  describe '.domains' do
    let(:request) { instance_double(Request) }
    let(:response) { instance_double(HTTP::Response, code: 200, body: payload.to_json) }
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
  end
end
