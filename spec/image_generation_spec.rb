require "spec_helper"
require "tmpdir"
require "vips"
require "net/http"
require "image_generation"
require "scryfall/card"

# Golden-image spec: generates one card from a fixed fixture card and compares the
# output JPEG against a committed reference at spec/fixtures/golden_card.jpg.
#
# On first run (or when the golden is intentionally regenerated) set
# GOLDEN_REGEN=1 to write a new reference image rather than comparing.
#
# This test does NOT require fonts/NDPMTG.ttf; the fixture card uses plain oracle
# text with no inline mana symbols so only system fonts are exercised. The art
# download is stubbed with a 100% blue JPEG to make the test hermetic.
RSpec.describe ImageGeneration do
  GOLDEN_PATH = File.join(FIXTURES_DIR, "golden_card.jpg")
  STUB_ART_JPEG = File.expand_path("../spec/fixtures/stub_art.jpg", __dir__)

  # Maximum mean absolute pixel error we tolerate across RGBA channels (0-255).
  # Set generously to survive minor font hinting differences across environments.
  MAX_MEAN_ERROR = 5.0

  def fixture_card
    data = {
      "name" => "Grave Titan",
      "mana_cost" => "{4}{B}{B}",
      "oracle_text" => "When Grave Titan enters, create two 2/2 black Zombie creature tokens.",
      "type_line" => "Legendary Creature — Zombie Giant",
      "power" => "6",
      "toughness" => "6",
      "image_uris" => { "art_crop" => "https://stub.example/art" }
    }
    Scryfall::Card.new(data, 4, 4)
  end

  def make_stub_art
    return if File.exist?(STUB_ART_JPEG)

    FileUtils.mkdir_p(File.dirname(STUB_ART_JPEG))
    # 626×457 solid blue — same aspect ratio as Scryfall art_crop
    Vips::Image.black(626, 457).new_from_image([60, 100, 180]).write_to_file(STUB_ART_JPEG)
  end

  before(:all) do
    make_stub_art
    Dir.mkdir("output") unless Dir.exist?("output")
  end

  before do
    stub_request(:get, "https://stub.example/art")
      .to_return(status: 200, body: File.binread(STUB_ART_JPEG),
                 headers: { "Content-Type" => "image/jpeg" })
  end

  after do
    FileUtils.rm_f("output/grave_titan.jpg")
  end

  describe ".generate" do
    it "writes a JPEG with the same dimensions as the card template" do
      described_class.generate(fixture_card)

      output = Vips::Image.new_from_file("output/grave_titan.jpg")
      template = Vips::Image.new_from_file(Layout::CARD_TEMPLATE_FILE_NAME)

      expect(output.width).to eq(template.width)
      expect(output.height).to eq(template.height)
    end

    it "still renders a correctly-sized card when the art download fails" do
      stub_request(:get, "https://stub.example/art").to_return(status: 500)

      expect { described_class.generate(fixture_card) }
        .to output(/Could not download art/).to_stderr

      output = Vips::Image.new_from_file("output/grave_titan.jpg")
      template = Vips::Image.new_from_file(Layout::CARD_TEMPLATE_FILE_NAME)
      expect([output.width, output.height]).to eq([template.width, template.height])
    end

    it "produces output that matches the golden reference image within tolerance" do
      described_class.generate(fixture_card)

      output_path = "output/grave_titan.jpg"

      if ENV["GOLDEN_REGEN"] == "1" || !File.exist?(GOLDEN_PATH)
        FileUtils.mkdir_p(File.dirname(GOLDEN_PATH))
        FileUtils.cp(output_path, GOLDEN_PATH)
        skip "Golden reference created at #{GOLDEN_PATH} — rerun without GOLDEN_REGEN=1"
      end

      output = Vips::Image.new_from_file(output_path).colourspace(:srgb)
      golden = Vips::Image.new_from_file(GOLDEN_PATH).colourspace(:srgb)

      # Per-channel absolute difference, then mean across all pixels & channels
      diff = (output - golden).abs
      mean_error = diff.avg

      expect(mean_error).to be <= MAX_MEAN_ERROR,
        "Mean pixel error #{mean_error.round(2)} exceeds tolerance #{MAX_MEAN_ERROR}. " \
        "If this is an intentional rendering change, regenerate with GOLDEN_REGEN=1."
    end
  end
end
