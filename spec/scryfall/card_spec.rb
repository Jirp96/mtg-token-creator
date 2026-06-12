require "spec_helper"
require "scryfall/card"

# Characterization specs: these pin the CURRENT behavior of Scryfall::Card so the
# refactor stays behavior-preserving. They intentionally encode existing quirks
# (e.g. the double space in #type, ASCII-only #processed_name) rather than ideal
# behavior.
RSpec.describe Scryfall::Card do
  let(:plain_creature) do
    {
      "name" => "Grave Titan",
      "mana_cost" => "{4}{B}{B}",
      "oracle_text" => "When Grave Titan enters, create two 2/2 black Zombie creature tokens.",
      "type_line" => "Legendary Creature — Zombie Giant",
      "power" => "6",
      "toughness" => "6",
      "image_uris" => { "art_crop" => "https://img.example/grave_titan/art" }
    }
  end

  describe "#name / mana / oracle" do
    it "reads the top-level fields for a single-faced card" do
      card = described_class.new(plain_creature)

      expect(card.name).to eq("Grave Titan")
      expect(card.mana_cost).to eq("{4}{B}{B}")
      expect(card.oracle_text).to start_with("When Grave Titan enters")
    end
  end

  describe "#type" do
    it "renders a legendary, non-saga token with the historical double space" do
      card = described_class.new(plain_creature)

      expect(card.type).to eq("TOKEN Legendary Creature -  Zombie")
    end

    it "renders a saga token (enchantment + saga segments)" do
      saga = plain_creature.merge("type_line" => "Enchantment — Saga")
      card = described_class.new(saga)

      expect(card.is_legendary).to be(false)
      expect(card.is_saga).to be(true)
      expect(card.type).to eq("TOKEN Enchantment Creature - Saga Zombie")
    end

    it "renders a plain (non-legendary, non-saga) token" do
      plain = plain_creature.merge("type_line" => "Creature — Zombie")
      card = described_class.new(plain)

      expect(card.type).to eq("TOKEN Creature -  Zombie")
    end
  end

  describe "#stat_line and power/toughness" do
    it "falls back to the API power/toughness when none are supplied" do
      card = described_class.new(plain_creature)

      expect(card.stat_line).to eq("6/6")
    end

    it "uses explicit power/toughness overrides" do
      card = described_class.new(plain_creature, 4, 4)

      expect(card.stat_line).to eq("4/4")
    end
  end

  describe "#raw_cost" do
    it "strips the brace delimiters and preserves case" do
      card = described_class.new(plain_creature)

      expect(card.raw_cost).to eq("4BB")
    end
  end

  describe "#processed_name" do
    it "lowercases and underscore-joins a simple name" do
      card = described_class.new(plain_creature.merge("name" => "Grave Titan"))

      expect(card.processed_name).to eq("grave_titan")
    end

    it "drops punctuation such as commas" do
      card = described_class.new(plain_creature.merge("name" => "Armaggon, Future Shark"))

      expect(card.processed_name).to eq("armaggon_future_shark")
    end

    it "strips non-ASCII letters (current \\w behavior) but keeps hyphens" do
      card = described_class.new(plain_creature.merge("name" => "Troll of Khazad-dûm"))

      expect(card.processed_name).to eq("troll_of_khazad-dm")
    end
  end

  describe "art_crop_url resolution" do
    it "prefers an explicitly supplied url" do
      card = described_class.new(plain_creature, nil, nil, "https://override/art")

      expect(card.art_crop_url).to eq("https://override/art")
    end

    it "falls back to the top-level image_uris art_crop" do
      card = described_class.new(plain_creature)

      expect(card.art_crop_url).to eq("https://img.example/grave_titan/art")
    end

    it "falls back to the first card face art_crop when no top-level image_uris" do
      faced = {
        "name" => "Facey",
        "type_line" => "Creature — Zombie",
        "card_faces" => [
          { "name" => "Front", "image_uris" => { "art_crop" => "https://faces/front/art" } }
        ]
      }
      card = described_class.new(faced)

      expect(card.art_crop_url).to eq("https://faces/front/art")
    end
  end

  describe "prepared dual-faced cards" do
    let(:prepared) do
      {
        "keywords" => ["Prepared"],
        "type_line" => "Creature — Zombie // Instant",
        "card_faces" => [
          {
            "name" => "Emeritus of Ideation",
            "mana_cost" => "{2}{U}",
            "oracle_text" => "Front face text.",
            "image_uris" => { "art_crop" => "https://faces/front/art" }
          },
          {
            "name" => "Ancestral Recall",
            "mana_cost" => "{U}",
            "oracle_text" => "Draw three cards.",
            "type_line" => "Instant"
          }
        ]
      }
    end

    it "reads name/mana/oracle from the front face" do
      card = described_class.new(prepared)

      expect(card.name).to eq("Emeritus of Ideation")
      expect(card.mana_cost).to eq("{2}{U}")
      expect(card.oracle_text).to eq("Front face text.")
    end

    it "exposes the back face as second_face" do
      card = described_class.new(prepared)

      expect(card.second_face).to include("name" => "Ancestral Recall")
    end

    it "leaves second_face nil for non-prepared cards" do
      card = described_class.new(plain_creature)

      expect(card.second_face).to be_nil
    end
  end
end
