# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VirtualKemomimiRelayFeed do
  describe '#get' do
    subject(:status_ids) { described_class.new(viewer, options).get(20).map(&:id) }

    let(:viewer) { Fabricate(:account) }
    let(:options) { {} }

    before do
      allow(VirtualKemomimiRelay::ServerList).to receive(:domains).and_return(['allowed.example'])
    end

    it 'includes public statuses from relay-listed servers' do
      allowed_account = Fabricate(:account, domain: 'allowed.example')
      allowed_status = Fabricate(:status, account: allowed_account)

      expect(status_ids).to include(allowed_status.id)
    end

    it 'includes public statuses from local accounts' do
      local_account = Fabricate(:account, domain: nil)
      local_status = Fabricate(:status, account: local_account)

      expect(status_ids).to include(local_status.id)
    end

    it 'excludes public statuses from servers not listed by the relay' do
      unlisted_account = Fabricate(:account, domain: 'unlisted.example')
      unlisted_status = Fabricate(:status, account: unlisted_account)

      expect(status_ids).to_not include(unlisted_status.id)
    end

    it 'includes the viewers own public statuses' do
      own_status = Fabricate(:status, account: viewer)

      expect(status_ids).to include(own_status.id)
    end

    it 'excludes the viewers own non-public statuses' do
      own_private_status = Fabricate(:status, account: viewer, visibility: :private)

      expect(status_ids).to_not include(own_private_status.id)
    end

    it 'excludes boosts when reblogs are disabled' do
      original_status = Fabricate(:status, account: Fabricate(:account, domain: 'allowed.example'))
      boost = Fabricate(:status, account: Fabricate(:account, domain: 'allowed.example'), reblog_of_id: original_status.id)

      expect(described_class.new(viewer, with_reblogs: false).get(20).map(&:id)).to_not include(boost.id)
    end

    it 'excludes replies when replies are disabled' do
      original_status = Fabricate(:status, account: Fabricate(:account, domain: 'allowed.example'))
      reply = Fabricate(:status, account: Fabricate(:account, domain: 'allowed.example'), in_reply_to_id: original_status.id, in_reply_to_account_id: original_status.account_id)

      expect(described_class.new(viewer, with_replies: false).get(20).map(&:id)).to_not include(reply.id)
    end

    it 'excludes quotes when quotes are disabled' do
      quoted_status = Fabricate(:status, account: Fabricate(:account, domain: 'allowed.example'))
      quote_status = Fabricate(:status, account: Fabricate(:account, domain: 'allowed.example'))
      Fabricate(:quote, status: quote_status, quoted_status: quoted_status, state: :accepted)

      expect(described_class.new(viewer, with_quotes: false).get(20).map(&:id)).to_not include(quote_status.id)
    end

    context 'with social option' do
      let(:options) { { include_followed: true } }

      it 'includes public statuses from followed accounts' do
        followed_account = Fabricate(:account, domain: 'followed.example')
        viewer.follow!(followed_account)
        followed_status = Fabricate(:status, account: followed_account)

        expect(status_ids).to include(followed_status.id)
      end
    end
  end
end
