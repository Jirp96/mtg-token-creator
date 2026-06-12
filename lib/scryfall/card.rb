module Scryfall
  class Card
    attr_reader :name, :mana_cost, :oracle_text, :art_crop_url, :second_face
    attr_accessor :power, :toughness

    def initialize(api_card_info, power = nil, toughness = nil, art_crop_url = nil)
      prepared = (api_card_info["keywords"] || []).any? { |k| k.casecmp?("prepared") }
      face     = prepared ? (api_card_info.dig("card_faces", 0) || api_card_info) : api_card_info

      @name        = face["name"]
      @mana_cost   = face["mana_cost"]
      @oracle_text = face["oracle_text"]
      type_line    = api_card_info["type_line"] || api_card_info.dig("card_faces", 0, "type_line") || ""
      @legendary   = type_line.include?("Legendary")
      @saga        = type_line.include?("Saga")
      @art_crop_url = art_crop_url ||
                      api_card_info.dig("image_uris", "art_crop") ||
                      api_card_info.dig("card_faces", 0, "image_uris", "art_crop")
      @second_face = prepared ? api_card_info.dig("card_faces", 1) : nil
      @power       = power.nil? ? api_card_info["power"] : power
      @toughness   = toughness.nil? ? api_card_info["toughness"] : toughness
    end

    def legendary?
      @legendary
    end

    def saga?
      @saga
    end

    def type
      "TOKEN #{"Legendary " if @legendary}#{"Enchantment " if @saga}Creature - #{"Saga" if @saga} Zombie"
    end

    def stat_line
      "#{@power}/#{@toughness}"
    end

    def raw_cost
      self.class.strip_mana_cost(mana_cost)
    end

    def processed_name
      name.to_s.gsub(/[^\w\s_-]+/, "")
          .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
          .gsub(/\s+/, "_")
          .downcase
    end

    # Strip the {…} delimiters from a Scryfall mana-cost string,
    # e.g. "{4}{B}{B}" => "4BB".
    def self.strip_mana_cost(mana_cost)
      mana_cost.to_s.tr("{", "").split("}").join
    end
  end
end
