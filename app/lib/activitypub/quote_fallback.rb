# frozen_string_literal: true

class ActivityPub::QuoteFallback
  class << self
    def remove(content, quote)
      return content unless quote&.accepted? && quote.quoted_status.present?

      quote_urls = [
        ActivityPub::TagManager.instance.url_for(quote.quoted_status),
        ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
      ].compact
      return content if quote_urls.empty?

      fragment = Nokogiri::HTML5.fragment(content)
      quote_fallback = matching_fallback(fragment, quote_urls)
      return content if quote_fallback.nil?

      remove_preceding_breaks(quote_fallback)
      quote_fallback.remove
      fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety
    end

    def expose(content, quote)
      return content unless quote&.quoted_status&.implicit_public_quote_policy?

      fragment = Nokogiri::HTML5.fragment(content)
      quote_fallback = fragment.at_css('p.quote-inline')
      return content if quote_fallback.nil?

      quote_fallback.delete('class')
      fragment.to_html
    end

    private

    def matching_fallback(fragment, quote_urls)
      edge_nodes = fragment.children.select { |node| node.element? || node.text.strip.present? }.then { |nodes| [nodes.first, nodes.last] }
      candidates = fragment.css('.quote-inline').to_a + edge_nodes

      candidates.compact.uniq.find do |node|
        node.element? && node.text.squish.start_with?('RE:') && node.css('a[href]').any? { |link| quote_urls.include?(link['href']) }
      end
    end

    def remove_preceding_breaks(quote_fallback)
      return unless quote_fallback.name == 'span'

      2.times do
        previous_sibling = quote_fallback.previous_sibling
        break unless previous_sibling&.element? && previous_sibling.name == 'br'

        previous_sibling.remove
      end
    end
  end
end
