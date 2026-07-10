# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::AcceptImplicitQuoteWorker do
  subject(:perform) { described_class.new.perform(quote.id) }

  let(:quoted_account) { Fabricate(:account, domain: 'quoted.example') }
  let(:quoted_status) { Fabricate(:status, account: quoted_account, visibility: :public, quote_approval_policy: quote_approval_policy) }
  let(:status) { Fabricate(:status) }
  let(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, state: quote_state) }
  let(:quote_approval_policy) { 0 }
  let(:quote_state) { :pending }

  before do
    allow(DistributionWorker).to receive(:perform_async)
  end

  it 'accepts an implicitly allowed quote and distributes a silent update' do
    expect { perform }
      .to change { quote.reload.state }.from('pending').to('accepted')

    expect(DistributionWorker)
      .to have_received(:perform_async).with(status.id, { 'update' => true, 'skip_notifications' => true })
  end

  context 'when the quoted post has an explicit quote policy' do
    let(:quote_approval_policy) { Status::QUOTE_APPROVAL_POLICY_PRESENT_FLAG }

    it 'leaves the quote pending' do
      expect { perform }
        .to_not change { quote.reload.state }.from('pending')

      expect(DistributionWorker).to_not have_received(:perform_async)
    end
  end

  context 'when the quote is already accepted' do
    let(:quote_state) { :accepted }

    it 'does not distribute another update' do
      expect { perform }
        .to_not change { quote.reload.state }.from('accepted')

      expect(DistributionWorker).to_not have_received(:perform_async)
    end
  end

  context 'when the quote no longer exists' do
    it 'returns successfully' do
      quote.destroy!

      expect(perform).to be(true)
    end
  end

  describe '.enqueue_pending' do
    subject(:enqueue_pending) { described_class.enqueue_pending(dry_run:) }

    let(:dry_run) { false }
    let!(:eligible_quote) { quote }
    let!(:explicit_quote) do
      Fabricate(
        :quote,
        status: Fabricate(:status, account: Fabricate(:account, domain: 'quoting.example')),
        quoted_status: Fabricate(:status, account: Fabricate(:account, domain: 'explicit.example'), quote_approval_policy: Status::QUOTE_APPROVAL_POLICY_PRESENT_FLAG),
        state: :pending
      )
    end
    let!(:missing_quote) { Fabricate(:quote, quoted_status: nil, state: :pending) }

    it 'enqueues only implicitly allowed quotes' do
      expect(enqueue_pending).to eq 1
      expect(described_class).to have_enqueued_sidekiq_job(eligible_quote.id)
      expect(described_class).to_not have_enqueued_sidekiq_job(explicit_quote.id)
      expect(described_class).to_not have_enqueued_sidekiq_job(missing_quote.id)
    end

    context 'when running in dry-run mode' do
      let(:dry_run) { true }

      it 'counts eligible quotes without enqueueing jobs' do
        expect(enqueue_pending).to eq 1
        expect(described_class.jobs).to be_empty
      end
    end
  end

  describe '.enqueue_for' do
    subject(:enqueue_for) { described_class.enqueue_for(quoted_status) }

    let!(:pending_quote) { quote }
    let!(:accepted_quote) { Fabricate(:quote, status: Fabricate(:status), quoted_status: quoted_status, state: :accepted) }

    it 'enqueues only pending quotes for the quoted post' do
      expect(enqueue_for).to eq 1
      expect(described_class).to have_enqueued_sidekiq_job(pending_quote.id)
      expect(described_class).to_not have_enqueued_sidekiq_job(accepted_quote.id)
    end

    context 'when the quoted post is not implicitly quotable' do
      before do
        quoted_status.update!(quote_approval_policy: Status::QUOTE_APPROVAL_POLICY_PRESENT_FLAG)
      end

      it 'does not enqueue quotes' do
        expect(enqueue_for).to eq 0
        expect(described_class.jobs).to be_empty
      end
    end
  end
end
