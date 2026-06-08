# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormattingHelper do
  include Devise::Test::ControllerHelpers

  describe '#status_content_format' do
    subject { helper.status_content_format(status) }

    let(:account) { Fabricate(:account, domain: 'example.com') }
    let(:quoted_status) { Fabricate(:status, account: Fabricate(:account, domain: 'quoted.example'), uri: 'https://quoted.example/notes/abc123', url: 'https://quoted.example/notes/abc123') }
    let(:status) { Fabricate(:status, account: account, text: text) }
    let(:text) { '<p>RE: <a href="https://quoted.example/notes/abc123">notes/abc123</a></p><p>Hello</p>' }

    before do
      Fabricate(:quote, status: status, quoted_status: quoted_status, state: quote_state)
    end

    context 'with an accepted remote quote fallback' do
      let(:quote_state) { :accepted }

      it 'strips the fallback paragraph' do
        expect(subject).to eq '<p>Hello</p>'
      end
    end

    context 'with a pending remote quote fallback' do
      let(:quote_state) { :pending }

      it 'keeps the fallback paragraph' do
        expect(subject).to include 'RE:'
      end
    end

    context 'when the fallback points elsewhere' do
      let(:quote_state) { :accepted }
      let(:text) { '<p>RE: <a href="https://other.example/notes/abc123">notes/abc123</a></p><p>Hello</p>' }

      it 'keeps the paragraph' do
        expect(subject).to include 'RE:'
      end
    end
  end

  describe '#rss_status_content_format' do
    subject { helper.rss_status_content_format(status) }

    context 'with a simple status' do
      let(:status) { Fabricate.build :status, text: 'Hello world' }

      it 'renders the formatted elements' do
        expect(parsed_result.css('p').first.text)
          .to eq('Hello world')
      end
    end

    context 'with a spoiler and an emoji and a poll' do
      let(:status) { Fabricate(:status, text: 'Hello :world: <>', spoiler_text: 'This is a spoiler<>', poll: Fabricate(:poll, options: %w(Yes<> No))) }

      before { Fabricate :custom_emoji, shortcode: 'world' }

      it 'renders the formatted elements' do
        expect(spoiler_node.css('strong').text)
          .to eq('Content warning:')
        expect(spoiler_node.text)
          .to include('This is a spoiler<>')
        expect(content_node.text)
          .to eq('Hello  <>')
        expect(content_node.css('img').first.to_h.symbolize_keys)
          .to include(
            rel: 'emoji',
            title: ':world:'
          )
        expect(poll_node.css('radio').first.text)
          .to eq('Yes<>')
        expect(poll_node.css('radio').first.to_h.symbolize_keys)
          .to include(
            disabled: 'disabled'
          )
      end

      def spoiler_node
        parsed_result.css('p').first
      end

      def content_node
        parsed_result.css('p')[1]
      end

      def poll_node
        parsed_result.css('p').last
      end
    end

    def parsed_result
      Nokogiri::HTML.fragment(subject)
    end
  end
end
