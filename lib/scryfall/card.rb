module Scryfall
  class Card    
    attr_reader :name, :mana_cost, :oracle_text, :is_legendary, :art_crop_url

    def initialize(apiCardInfo)
      @cardInfo = apiCardInfo
      @name = apiCardInfo["name"]
      @mana_cost = apiCardInfo["mana_cost"]
      @oracle_text = apiCardInfo["oracle_text"]
      @is_legendary = apiCardInfo["type_line"].include? "Legendary"
      @art_crop_url = apiCardInfo["image_uris"]["art_crop"]
    end
  end
end