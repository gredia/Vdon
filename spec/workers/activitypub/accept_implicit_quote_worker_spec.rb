# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::AcceptImplicitQuoteWorker do
  subject(:perform) { described_class.new.perform(quote.id) }

  let(:quoted_account) { Fabricate(:account, domain: 'quoted.example') }
  let(:quoted_status) { Fabricate(:status, account: quoted_account, visibility: :public, quote_approval_policy: quote_approval_policy) }
  let(:status) { Fabricate(:status) }
  let(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, state: quote_state) }
  let(:quote_approval_policy) { InteractionPolicy::POLICY_FLAGS[:public] << 16 }
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
    let(:quote_approval_policy) { Status::InteractionPolicyConcern::QUOTE_POLICY_EXPLICIT_FLAG }

    it 'leaves the quote pending' do
      expect { perform }
        .to_not change { quote.reload.state }.from('pending')

      expect(DistributionWorker).to_not have_received(:perform_async)
    end
  end

  context 'when the quoted post has an unknown historical quote policy' do
    let(:quote_approval_policy) { 0 }

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
end
