# frozen_string_literal: true

module VirtualKemomimiRelay
  class ServerList
    URL = 'https://relay.virtualkemomimi.net/api/servers'
    CACHE_KEY = 'virtual_kemomimi_relay/server_list'
    CACHE_TTL = 1.week

    class << self
      def domains
        Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_domains }
      rescue HTTP::Error, HTTP::TimeoutError, Addressable::URI::InvalidURIError, Oj::ParseError, Mastodon::HostValidationError
        []
      end

      private

      def fetch_domains
        Request.new(:get, URL).add_headers('Accept' => 'application/json').perform do |response|
          return [] unless response.code == 200

          normalize(Oj.load(response.body.to_s))
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

        return if value.blank?

        value = Addressable::URI.parse(value).host if value.start_with?('http://', 'https://')
        value&.downcase&.delete_prefix('@')&.presence
      rescue Addressable::URI::InvalidURIError
        nil
      end
    end
  end
end
