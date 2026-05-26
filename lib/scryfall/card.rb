module Scryfall
  class Card
    attr_reader :name, :mana_cost, :oracle_text, :is_legendary, :art_crop_url
    attr_accessor :power, :toughness, :is_saga

    def initialize(apiCardInfo, power=nil, toughness=nil, art_crop_url=nil)
      @cardInfo     = apiCardInfo
      @name         = apiCardInfo["name"]
      @mana_cost    = apiCardInfo["mana_cost"]
      @oracle_text  = apiCardInfo["oracle_text"]
      @is_legendary = apiCardInfo["type_line"].include? "Legendary"
      @is_saga      = apiCardInfo["type_line"].include? "Saga"
      @art_crop_url = art_crop_url || apiCardInfo["image_uris"]["art_crop"]
      @power        = if power.nil?
                        apiCardInfo["power"]
                      else
                        power
                      end

      @toughness    = if toughness.nil?
                        apiCardInfo["toughness"]
                      else
                        toughness
                      end
    end

    def type
      "TOKEN #{"Legendary " if @is_legendary}#{"Enchantment " if @is_saga}Creature - #{"Saga" if @is_saga} Zombie"
    end

    def stat_line
      "#{@power}/#{@toughness}"
    end

    def mana_simbols
      pips = {"colorless": 0, "W": 0, "U": 0, "R":0, "B": 0, "G": 0, "X": 0}
      cost_list = mana_cost.tr("{", "").split("}")

      cost_list.each do |pip|
        if "WURBGX".include? pip
          pips[pip.to_sym] += 1
        else
          pips[:colorless] += 1
        end
      end

      pips
    end

    def raw_cost
      mana_cost.tr("{", "").split("}").join("")
    end

    def processed_name
      name.gsub(/[^\w\s_-]+/, '')
            .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
            .gsub(/\s+/, '_')
            .downcase
    end

  end
end
