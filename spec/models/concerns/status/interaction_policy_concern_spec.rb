# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Status::InteractionPolicyConcern do
  let(:status) { Fabricate(:status, quote_approval_policy: (0b0101 << 16) | 0b0010) }

  describe '#quote_policy_as_keys' do
    it 'returns the expected values' do
      expect(status.quote_policy_as_keys(:automatic)).to eq ['unsupported_policy', 'followers']
      expect(status.quote_policy_as_keys(:manual)).to eq ['public']
    end
  end

  describe '#quote_policy_for_account' do
    let(:account) { Fabricate(:account) }

    context 'when the account is the author' do
      let(:status) { Fabricate(:status, account: account, quote_approval_policy: 0) }

      it 'returns :automatic' do
        expect(status.quote_policy_for_account(account)).to eq :automatic
      end

      context 'when it is a reblog' do
        let(:status) { Fabricate(:status, account: account, quote_approval_policy: 0, reblog: Fabricate(:status)) }

        it 'returns :automatic' do
          expect(status.quote_policy_for_account(account)).to eq :denied
        end
      end
    end

    context 'when the account is not following the user' do
      it 'returns :manual because of the public entry in the manual policy' do
        expect(status.quote_policy_for_account(account)).to eq :manual
      end
    end

    context 'when the account is following the user' do
      before do
        account.follow!(status.account)
      end

      it 'returns :automatic because of the followers entry in the automatic policy' do
        expect(status.quote_policy_for_account(account)).to eq :automatic
      end
    end

    context 'when the account falls into the unknown bucket' do
      let(:status) { Fabricate(:status, quote_approval_policy: (0b0001 << 16) | 0b0100) }

      it 'returns :automatic because of the followers entry in the automatic policy' do
        expect(status.quote_policy_for_account(account)).to eq :unknown
      end
    end

    context 'with a remote public post without an explicit quote policy' do
      let(:status) { Fabricate(:status, account: Fabricate(:account, domain: 'misskey.example'), visibility: :public, quote_approval_policy: 0) }

      it 'returns :automatic' do
        expect(status.quote_policy_for_account(account)).to eq :automatic
      end
    end

    context 'with a remote public post with an implicit quote policy' do
      let(:status) { Fabricate(:status, account: Fabricate(:account, domain: 'misskey.example'), visibility: :public, quote_approval_policy: Status::QUOTE_APPROVAL_POLICY_FLAGS[:public] << 16) }

      it 'returns :automatic' do
        expect(status.quote_policy_for_account(account)).to eq :automatic
      end

      it 'does not need a quote request' do
        expect(status).to_not be_quote_request_needed
      end
    end

    context 'with a remote unlisted post without an explicit quote policy' do
      let(:status) { Fabricate(:status, account: Fabricate(:account, domain: 'misskey.example'), visibility: :unlisted, quote_approval_policy: 0) }

      it 'returns :automatic' do
        expect(status.quote_policy_for_account(account)).to eq :automatic
      end
    end

    context 'with a remote followers-only post without an explicit quote policy' do
      let(:status) { Fabricate(:status, account: Fabricate(:account, domain: 'misskey.example'), visibility: :private, quote_approval_policy: 0) }

      it 'returns :denied' do
        expect(status.quote_policy_for_account(account)).to eq :denied
      end
    end

    context 'with a remote post with an explicit quote policy denying quotes' do
      let(:status) { Fabricate(:status, account: Fabricate(:account, domain: 'mastodon.example'), visibility: :public, quote_approval_policy: Status::QUOTE_APPROVAL_POLICY_PRESENT_FLAG) }

      it 'returns :denied' do
        expect(status.quote_policy_for_account(account)).to eq :denied
      end
    end
  end
end
