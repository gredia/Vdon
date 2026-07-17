# frozen_string_literal: true

module VirtualKemomimiRelay
  class ServerList
    URL = 'https://relay.virtualkemomimi.net/api/servers'
    CACHE_KEY = 'virtual_kemomimi_relay/server_list'
    CACHE_TTL = 1.week
    CACHE_RACE_TTL = 10.seconds

    class FetchError < StandardError; end

    class << self
      def domains
        Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL, race_condition_ttl: CACHE_RACE_TTL) { fetch_domains }
      rescue FetchError, HTTP::Error, HTTP::TimeoutError, Addressable::URI::InvalidURIError, JSON::ParserError, Mastodon::HostValidationError, Mastodon::LengthValidationError
        []
      end

      private

      def fetch_domains
        Request.new(:get, URL).add_headers('Accept' => 'application/json').perform do |response|
          raise FetchError, "Relay server list returned HTTP #{response.code}" unless response.code == 200

          normalize(JSON.parse(response.body_with_limit))
        end
      end

      def normalize(payload)
        extract_entries(payload).filter_map { |entry| normalize_entry(entry) }.uniq
      end

      def extract_entries(payload)
        case payload
        when Array
          payload
        when Hash
          payload['servers'] || payload['domains'] || payload['data'] || payload['items'] || []
        else
          []
        end
      end

      def normalize_entry(entry)
        value = case entry
                when String
                  entry
                when Hash
                  entry['domain'] || entry['host'] || entry['server'] || entry['url'] || entry['Url']
                end

        return unless value.is_a?(String)

        value = value.strip.delete_prefix('@')
        return if value.blank?

        candidate = value.start_with?('http://', 'https://') ? value : "https://#{value}"
        Addressable::URI.parse(candidate).host&.downcase&.delete_suffix('.')&.presence
      rescue Addressable::URI::InvalidURIError
        nil
      end
    end
  end
end
