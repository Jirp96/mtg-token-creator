require "http"

CARD_API_URL = "https://api.scryfall.com/cards/named"

module Scryfall
  class Cards
    def self.get(name)
      sleep(0.1)
      HTTP["accept": "application/json", "User-Agent": "Hashaton-Token-Maker"]
        .get(CARD_API_URL, params: {exact: name})
    end
  end
end