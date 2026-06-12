require "spec_helper"
require "json"
require "scryfall/cards"

# Characterization specs for the Scryfall API client. Network is fully stubbed
# with WebMock so these are deterministic and offline.
RSpec.describe Scryfall::Cards do
  def json_response(hash)
    { status: 200, body: hash.to_json, headers: { "Content-Type" => "application/json" } }
  end

  describe ".parse_scryfall_card_url" do
    it "extracts set code and collector number from a card url" do
      result = described_class.parse_scryfall_card_url("https://scryfall.com/card/fin/100/malboro")

      expect(result).to eq(set_code: "fin", collector_number: "100")
    end

    it "decodes a url-encoded collector number" do
      result = described_class.parse_scryfall_card_url("https://scryfall.com/card/fin/100%E2%98%85")

      expect(result[:collector_number]).to eq("100★")
    end

    it "returns nil for a non-scryfall host" do
      expect(described_class.parse_scryfall_card_url("https://example.com/card/fin/100")).to be_nil
    end

    it "returns nil for a non-card path" do
      expect(described_class.parse_scryfall_card_url("https://scryfall.com/sets/fin")).to be_nil
    end

    it "returns nil for a path without a collector number" do
      expect(described_class.parse_scryfall_card_url("https://scryfall.com/card/fin")).to be_nil
    end

    it "returns nil for a non-http(s) scheme" do
      expect(described_class.parse_scryfall_card_url("ftp://scryfall.com/card/fin/100")).to be_nil
    end
  end

  describe ".scryfall_card_url?" do
    it "is true for a valid scryfall card url" do
      expect(described_class.scryfall_card_url?("https://scryfall.com/card/fin/100")).to be(true)
    end

    it "is false for anything else" do
      expect(described_class.scryfall_card_url?("just a name")).to be(false)
    end
  end

  describe ".get" do
    it "requests the named endpoint with an exact match param" do
      stub = stub_request(:get, "https://api.scryfall.com/cards/named")
             .with(query: { exact: "Grave Titan" })
             .to_return(json_response("name" => "Grave Titan"))

      response = described_class.get("Grave Titan")

      expect(response.parse).to eq("name" => "Grave Titan")
      expect(stub).to have_been_requested
    end
  end

  describe ".get_by_set_and_number" do
    it "requests the specific printing and returns the parsed body" do
      stub_request(:get, "https://api.scryfall.com/cards/fin/100")
        .to_return(json_response("name" => "Malboro", "set" => "fin"))

      result = described_class.get_by_set_and_number("fin", "100")

      expect(result).to include("name" => "Malboro", "set" => "fin")
    end
  end

  describe ".get_print_from_uri" do
    it "follows pagination until a matching set code is found" do
      page1 = "https://api.scryfall.com/cards/search?page=1"
      page2 = "https://api.scryfall.com/cards/search?page=2"

      stub_request(:get, page1).to_return(json_response(
        "data" => [{ "set" => "abc" }],
        "has_more" => true,
        "next_page" => page2
      ))
      stub_request(:get, page2).to_return(json_response(
        "data" => [{ "set" => "fin", "name" => "Malboro" }],
        "has_more" => false
      ))

      result = described_class.get_print_from_uri(page1, "FIN")

      expect(result).to include("set" => "fin", "name" => "Malboro")
    end

    it "returns nil when no printing matches the set code" do
      page = "https://api.scryfall.com/cards/search?page=1"
      stub_request(:get, page).to_return(json_response(
        "data" => [{ "set" => "abc" }],
        "has_more" => false
      ))

      expect(described_class.get_print_from_uri(page, "fin")).to be_nil
    end
  end
end
