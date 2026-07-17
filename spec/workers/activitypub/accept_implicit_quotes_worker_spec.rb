# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::AcceptImplicitQuotesWorker do
  subject(:perform) { described_class.new.perform(quoted_status.id) }

  let(:quoted_status) do
    Fabricate(
      :status,
      account: Fabricate(:account, domain: 'quoted.example'),
      visibility: :public,
      quote_approval_policy: InteractionPolicy::POLICY_FLAGS[:public] << 16
    )
  end

  let!(:pending_quote) { Fabricate(:quote, status: Fabricate(:status), quoted_status: quoted_status, state: :pending) }
  let!(:accepted_quote) { Fabricate(:quote, status: Fabricate(:status), quoted_status: quoted_status, state: :accepted) }

  it 'enqueues only pending quotes for the quoted post' do
    perform

    expect(ActivityPub::AcceptImplicitQuoteWorker).to have_enqueued_sidekiq_job(pending_quote.id)
    expect(ActivityPub::AcceptImplicitQuoteWorker).to_not have_enqueued_sidekiq_job(accepted_quote.id)
  end

  context 'when the quoted post is no longer implicitly quotable' do
    before do
      quoted_status.update!(quote_approval_policy: Status::InteractionPolicyConcern::QUOTE_POLICY_EXPLICIT_FLAG)
    end

    it 'does not enqueue quotes' do
      perform

      expect(ActivityPub::AcceptImplicitQuoteWorker.jobs).to be_empty
    end
  end

  context 'when the quoted post has an unknown historical quote policy' do
    before do
      quoted_status.update!(quote_approval_policy: 0)
    end

    it 'does not enqueue quotes' do
      perform

      expect(ActivityPub::AcceptImplicitQuoteWorker.jobs).to be_empty
    end
  end

  context 'when the quoted post no longer exists' do
    it 'returns successfully' do
      quoted_status.destroy!

      expect(perform).to be(true)
    end
  end
end
