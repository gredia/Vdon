# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::QuoteRefetchScheduler do
  let(:quote) { Fabricate(:quote, quoted_status: quoted_status, state: quote_state) }
  let(:quoted_status) { nil }
  let(:quote_state) { :pending }
  let(:quote_uri) { 'https://remote.example/notes/123' }
  let(:options) { { request_id: 'request-123', approval_uri: nil, allow_legacy_quote_approval: true } }

  before do
    allow(ActivityPub::RefetchAndVerifyQuoteWorker).to receive(:perform_in)
  end

  describe '.schedule_if_missing' do
    it 'schedules a retry with normalized worker options' do
      described_class.schedule_if_missing(quote, quote_uri, **options)

      expect(ActivityPub::RefetchAndVerifyQuoteWorker)
        .to have_received(:perform_in)
        .with(
          be_between(30.seconds, 600.seconds),
          quote.id,
          quote_uri,
          { 'request_id' => 'request-123', 'approval_uri' => nil, 'allow_legacy_quote_approval' => true }
        )
    end

    context 'when the quoted post is already present' do
      let(:quoted_status) { Fabricate(:status) }

      it 'does not schedule a retry' do
        described_class.schedule_if_missing(quote, quote_uri, **options)

        expect(ActivityPub::RefetchAndVerifyQuoteWorker).to_not have_received(:perform_in)
      end
    end
  end

  describe '.schedule' do
    context 'when the quoted post is already present' do
      let(:quoted_status) { Fabricate(:status) }

      it 'still schedules an approval retry' do
        described_class.schedule(quote, quote_uri, **options)

        expect(ActivityPub::RefetchAndVerifyQuoteWorker)
          .to have_received(:perform_in)
          .with(
            be_between(30.seconds, 600.seconds),
            quote.id,
            quote_uri,
            { 'request_id' => 'request-123', 'approval_uri' => nil, 'allow_legacy_quote_approval' => true }
          )
      end
    end

    context 'when the quote URI is blank' do
      let(:quote_uri) { nil }

      it 'does not schedule a retry' do
        described_class.schedule(quote, quote_uri, **options)

        expect(ActivityPub::RefetchAndVerifyQuoteWorker).to_not have_received(:perform_in)
      end
    end

    context 'when the quote has been deleted' do
      let(:quote_state) { :deleted }

      it 'does not schedule a retry' do
        described_class.schedule(quote, quote_uri, **options)

        expect(ActivityPub::RefetchAndVerifyQuoteWorker).to_not have_received(:perform_in)
      end
    end
  end
end
