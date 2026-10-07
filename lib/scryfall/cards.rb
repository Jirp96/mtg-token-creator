require "http"
require "uri"

module Scryfall
  class Cards
    CARD_API_URL = "https://api.scryfall.com/cards/named".freeze
    CARD_PRINT_API_URL = "https://api.scryfall.com/cards".freeze

    def self.get(name)
      request(CARD_API_URL, params: { exact: name })
    end

    def self.get_print_from_uri(prints_search_uri, set_code)
      next_page = prints_search_uri
      normalized_set_code = set_code.downcase

      while next_page
        response = request(next_page)
        print_list = response.parse

        matching_print = print_list["data"].find do |card_print|
          card_print["set"].downcase == normalized_set_code
        end

        return matching_print if matching_print

        next_page = print_list["has_more"] ? print_list["next_page"] : nil
      end

      nil
    end

    def self.get_by_set_and_number(set_code, collector_number)
      path_set_code = URI.encode_www_form_component(set_code)
      path_collector_number = URI.encode_www_form_component(collector_number)
      response = request("#{CARD_PRINT_API_URL}/#{path_set_code}/#{path_collector_number}")

      response.parse
    end

    def self.parse_scryfall_card_url(url)
      uri = URI.parse(url)
      return nil unless ["http", "https"].include?(uri.scheme)
      return nil unless uri.host&.end_with?("scryfall.com")

      path_parts = uri.path.split("/").reject(&:empty?)
      return nil unless path_parts[0] == "card"
      return nil unless path_parts.length >= 3

      {
        set_code: path_parts[1],
        collector_number: URI.decode_www_form_component(path_parts[2])
      }
    rescue URI::InvalidURIError
      nil
    end

    def self.scryfall_card_url?(value)
      !parse_scryfall_card_url(value).nil?
    end

    # Scryfall allows up to 10 req/s (100ms per request). We add 20ms of
    # headroom to stay safely within the limit. Override with SCRYFALL_DELAY=<seconds>.
    REQUEST_DELAY = ENV.fetch("SCRYFALL_DELAY", 0.5).to_f

    def self.request(url, params: nil)
      sleep(REQUEST_DELAY)
      HTTP[accept: "application/json", "User-Agent": "Hashaton-Token-Maker"]
        .get(url, params: params)
    end
  end
end
