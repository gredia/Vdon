# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::RefetchAndVerifyQuoteWorker do
  let(:worker) { described_class.new }
  let(:service) { instance_double(ActivityPub::VerifyQuoteService, call: true) }

  describe '#perform' do
    before { stub_service }

    let(:account) { Fabricate(:account, domain: 'example.com') }
    let(:status)  { Fabricate(:status, account: account) }
    let(:quote)   { Fabricate(:quote, status: status, quoted_status: Fabricate(:status)) }
    let(:url) { 'https://example.com/quoted-status' }
    let(:approval_uri) { 'https://example.com/approval-uri' }

    it 'sends the status to the service' do
      worker.perform(quote.id, url, { 'approval_uri' => approval_uri })

      expect(service).to have_received(:call).with(quote, approval_uri, fetchable_quoted_uri: url, request_id: anything, allow_legacy_quote_approval: false)
    end

    it 'passes legacy quote approval through to the service' do
      worker.perform(quote.id, url, { 'approval_uri' => approval_uri, 'allow_legacy_quote_approval' => true })

      expect(service).to have_received(:call).with(quote, approval_uri, fetchable_quoted_uri: url, request_id: anything, allow_legacy_quote_approval: true)
    end

    context 'with the old format' do
      it 'sends the status to the service' do
        worker.perform(quote.id, url)

        expect(service).to have_received(:call).with(quote, nil, fetchable_quoted_uri: url, request_id: anything, allow_legacy_quote_approval: false)
      end
    end

    it 'returns nil for non-existent record' do
      result = worker.perform(123_123_123, url)

      expect(result).to be(true)
    end

    context 'when the quoted status is still missing' do
      let(:quote) { Fabricate(:quote, status: status, quoted_status: nil) }

      it 'raises so Sidekiq retries the fetch' do
        expect { worker.perform(quote.id, url) }
          .to raise_error(described_class::MissingQuotedStatusError)
      end
    end

    context 'when the quote is accepted during verification' do
      let(:quote) { Fabricate(:quote, status: status, quoted_status: nil) }
      let(:quoted_status) { Fabricate(:status, account: Fabricate(:account, domain: 'quoted.example')) }

      before do
        allow(DistributionWorker).to receive(:perform_async)
        allow(service).to receive(:call) do |worker_quote|
          worker_quote.update!(quoted_status: quoted_status)
          worker_quote.accept!
        end
      end

      it 'distributes an update locally' do
        worker.perform(quote.id, url)

        expect(DistributionWorker)
          .to have_received(:perform_async).with(status.id, { 'update' => true })
      end
    end
  end

  def stub_service
    allow(ActivityPub::VerifyQuoteService)
      .to receive(:new)
      .and_return(service)
  end
end
