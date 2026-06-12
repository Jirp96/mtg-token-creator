module Scryfall
  class Card
    attr_reader :name, :mana_cost, :oracle_text, :is_legendary, :art_crop_url, :second_face
    attr_accessor :power, :toughness, :is_saga

    def initialize(apiCardInfo, power=nil, toughness=nil, art_crop_url=nil)
      @cardInfo = apiCardInfo

      prepared  = (apiCardInfo["keywords"] || []).any? { |k| k.casecmp?("prepared") }
      face      = prepared ? (apiCardInfo.dig("card_faces", 0) || apiCardInfo) : apiCardInfo

      @name         = face["name"]
      @mana_cost    = face["mana_cost"]
      @oracle_text  = face["oracle_text"]
      type_line     = apiCardInfo["type_line"] || apiCardInfo.dig("card_faces", 0, "type_line") || ""
      @is_legendary = type_line.include?("Legendary")
      @is_saga      = type_line.include?("Saga")
      @art_crop_url = art_crop_url ||
                      apiCardInfo.dig("image_uris", "art_crop") ||
                      apiCardInfo.dig("card_faces", 0, "image_uris", "art_crop")
      @second_face  = prepared ? apiCardInfo.dig("card_faces", 1) : nil
      @power        = power.nil? ? apiCardInfo["power"] : power
      @toughness    = toughness.nil? ? apiCardInfo["toughness"] : toughness
    end

    def type
      "TOKEN #{"Legendary " if @is_legendary}#{"Enchantment " if @is_saga}Creature - #{"Saga" if @is_saga} Zombie"
    end

    def stat_line
      "#{@power}/#{@toughness}"
    end

    def raw_cost
      mana_cost.tr("{", "").split("}").join("")
    end

    def processed_name
      name.to_s.gsub(/[^\w\s_-]+/, "")
            .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
            .gsub(/\s+/, "_")
            .downcase
    end

  end
end
