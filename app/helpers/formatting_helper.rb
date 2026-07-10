# frozen_string_literal: true

module FormattingHelper
  SYNDICATED_EMOJI_STYLES = <<~CSS.squish
    height: 1.1em;
    margin: -.2ex .15em .2ex;
    object-fit: contain;
    vertical-align: middle;
    width: 1.1em;
  CSS

  def html_aware_format(text, local, options = {})
    HtmlAwareFormatter.new(text, local, options).to_s
  end

  def linkify(text, options = {})
    TextFormatter.new(text, options).to_s
  end

  def url_for_preview_card(preview_card)
    preview_card.url
  end

  def extract_status_plain_text(status)
    PlainTextFormatter.new(status.text, status.local?).to_s
  end
  module_function :extract_status_plain_text

  def status_content_format(status)
    quoted_status = status.quote&.quoted_status if status.local?
    content = html_aware_format(status.text, status.local?, preloaded_accounts: [status.account] + (status.respond_to?(:active_mentions) ? status.active_mentions.map(&:account) : []), quoted_status: quoted_status)

    if !status.local? && status.quote.present?
      strip_remote_quote_fallback(content, status.quote)
    else
      content
    end
  end

  def rss_status_content_format(status)
    prerender_custom_emojis(
      wrapped_status_content_format(status),
      status.emojis,
      style: SYNDICATED_EMOJI_STYLES
    ).to_str
  end

  def account_bio_format(account)
    html_aware_format(account.note, account.local?)
  end

  def account_field_value_format(field, with_rel_me: true)
    if field.verified? && !field.account.local?
      TextFormatter.shortened_link(field.value_for_verification)
    else
      html_aware_format(field.value, field.account.local?, with_rel_me: with_rel_me, with_domains: true, multiline: false)
    end
  end

  def markdown(text)
    Redcarpet::Markdown.new(Redcarpet::Render::HTML, escape_html: true, no_images: true).render(text).html_safe # rubocop:disable Rails/OutputSafety
  end

  private

  def wrapped_status_content_format(status)
    safe_join [
      rss_content_preroll(status),
      status_content_format(status),
      rss_content_postroll(status),
    ]
  end

  def rss_content_preroll(status)
    return unless status.spoiler_text?

    safe_join [
      tag.p { spoiler_with_warning(status) },
      tag.hr,
    ]
  end

  def spoiler_with_warning(status)
    safe_join [
      tag.strong { I18n.t('rss.content_warning', locale: available_locale_or_nil(status.language) || I18n.default_locale) },
      status.spoiler_text,
    ]
  end

  def rss_content_postroll(status)
    return unless status.preloadable_poll

    tag.p do
      poll_option_tags(status)
    end
  end

  def poll_option_tags(status)
    safe_join(
      status.preloadable_poll.options.map do |option|
        tag.send(status.preloadable_poll.multiple? ? 'checkbox' : 'radio', option, disabled: true)
      end,
      tag.br
    )
  end

  def strip_remote_quote_fallback(content, quote)
    return content unless quote.accepted? && quote.quoted_status.present?

    strip_matching_remote_quote_fallback(content, quote.quoted_status)
  end

  def strip_matching_remote_quote_fallback(content, quoted_status)
    quote_urls = [
      ActivityPub::TagManager.instance.url_for(quoted_status),
      ActivityPub::TagManager.instance.uri_for(quoted_status),
    ].compact
    return content if quote_urls.empty?

    fragment = Nokogiri::HTML5.fragment(content)
    quote_fallback = remote_quote_fallback(fragment, quote_urls)
    return content if quote_fallback.nil?

    remove_preceding_quote_breaks(quote_fallback)
    quote_fallback.remove
    fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def remote_quote_fallback(fragment, quote_urls)
    edge_nodes = fragment.children.select { |node| node.element? || node.text.strip.present? }.then { |nodes| [nodes.first, nodes.last] }
    candidates = fragment.css('.quote-inline').to_a + edge_nodes

    candidates.compact.uniq.find do |node|
      node.element? && node.text.squish.start_with?('RE:') && node.css('a[href]').any? { |link| quote_urls.include?(link['href']) }
    end
  end

  def remove_preceding_quote_breaks(quote_fallback)
    return unless quote_fallback.name == 'span'

    2.times do
      previous_sibling = quote_fallback.previous_sibling
      break unless previous_sibling&.element? && previous_sibling.name == 'br'

      previous_sibling.remove
    end
  end
end
