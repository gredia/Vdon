# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quote do
  describe '#acceptable?' do
    subject { quote.acceptable? }

    let(:quote) { Fabricate(:quote, state: state, legacy: legacy) }
    let(:legacy) { false }
    let(:state) { :pending }

    it { is_expected.to be true }

    context 'with a pending legacy quote' do
      let(:legacy) { true }

      it { is_expected.to be true }
    end

    context 'with a rejected legacy quote' do
      let(:legacy) { true }
      let(:state) { :rejected }

      it { is_expected.to be false }
    end
  end

  describe '#accept_implicit_public_quote!' do
    subject(:accept_implicit_public_quote) { quote.accept_implicit_public_quote! }

    let(:account) { Fabricate(:account, domain: 'example.com') }
    let(:status) { Fabricate(:status, account: Fabricate(:account)) }
    let(:quoted_status) { Fabricate(:status, account: account, visibility: visibility, quote_approval_policy: quote_approval_policy) }
    let(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, state: state) }
    let(:visibility) { :public }
    let(:quote_approval_policy) { 0 }
    let(:state) { :pending }

    it 'accepts a pending quote of a remote public post without an explicit quote policy' do
      expect { accept_implicit_public_quote }
        .to change { quote.reload.state }.from('pending').to('accepted')
    end

    context 'when the quoted post has an explicit quote policy' do
      let(:quote_approval_policy) { Status::QUOTE_APPROVAL_POLICY_PRESENT_FLAG | (Status::QUOTE_APPROVAL_POLICY_FLAGS[:public] << 16) }

      it 'does not accept the quote' do
        expect { accept_implicit_public_quote }
          .to_not change { quote.reload.state }.from('pending')
      end
    end

    context 'when the quoted post is followers-only' do
      let(:visibility) { :private }

      before do
        quoted_status.update!(visibility: :public)
        quote
        quoted_status.update!(visibility: :private)
      end

      it 'does not accept the quote' do
        expect { accept_implicit_public_quote }
          .to_not change { quote.reload.state }.from('pending')
      end
    end

    context 'when the quote is already accepted' do
      let(:state) { :accepted }

      it 'does not change the quote' do
        expect(accept_implicit_public_quote).to be(false)
      end
    end
  end
end
