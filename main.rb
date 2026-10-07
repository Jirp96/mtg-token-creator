#!/usr/bin/ruby
require "bundler/setup"
require "csv"

require_relative "lib/scryfall"
require_relative "lib/image_generation"
require_relative "lib/pdf_generation"

# Reads card names (and optional art selectors) from a CSV, fetches each card
# from Scryfall, renders a token image, and assembles a printable PDF sheet.
class TokenCreator
  # Raised when the CLI is invoked without the required CSV argument.
  class UsageError < StandardError; end

  NAME_COLUMN         = 0
  ART_SELECTOR_COLUMN = 1
  ART_FOCUS_COLUMN    = 2
  OUTPUT_IMAGES_PATH  = "./output".freeze
  PDF_FILE_NAME       = "pdf_sheet".freeze
  DEFAULT_POWER       = 4
  DEFAULT_TOUGHNESS   = 4
  RATE_LIMIT_STATUS   = 429

  def self.run(argv)
    new.run(argv)
  end

  def run(argv)
    raise UsageError, "Usage: ruby main.rb <cards.csv>" if argv.empty?

    cards = load_cards(argv[0])
    render_images(cards)
    build_pdf
    delete_temporary_images
  end

  private

  def load_cards(csv_path)
    cards = []

    CSV.foreach(csv_path) do |row|
      card_name = csv_value(row, NAME_COLUMN)
      next if blank?(card_name)

      log "Processing '#{card_name}'"
      card = fetch_card(card_name, csv_value(row, ART_SELECTOR_COLUMN))
      next unless card

      card.art_focus = parse_art_focus(card_name, csv_value(row, ART_FOCUS_COLUMN))
      cards << card
    end

    cards
  end

  def fetch_card(card_name, art_selector)
    response = Scryfall::Cards.get(card_name)
    abort "Scryfall rate limit exceeded while fetching '#{card_name}'. Wait a moment and try again." if response.status.code == RATE_LIMIT_STATUS

    unless response.status.success?
      warn "Scryfall could not find '#{card_name}' (HTTP #{response.status.code}). Skipping."
      return nil
    end

    card_info = response.parse
    art_crop_url = resolve_art_crop_url(card_info, art_selector)
    Scryfall::Card.new(card_info, DEFAULT_POWER, DEFAULT_TOUGHNESS, art_crop_url)
  end

  def render_images(cards)
    log "Generating images"
    cards.each { |card| ImageGeneration.generate(card) }
  end

  def build_pdf
    log "Generating pdf"
    PdfGeneration.generate(OUTPUT_IMAGES_PATH, PDF_FILE_NAME)
  end

  def delete_temporary_images
    log "Deleting temporary images"
    Dir.glob("#{OUTPUT_IMAGES_PATH}/*.jpg").each do |file|
      File.delete(file)
    rescue StandardError => e
      warn "Could not delete temporary image #{file}: #{e.message}."
    end
  end

  def resolve_art_crop_url(card_info, art_selector)
    return nil if blank?(art_selector)

    selected_printing =
      if Scryfall::Cards.scryfall_card_url?(art_selector)
        printing_from_scryfall_url(art_selector)
      else
        printing_from_set_code(card_info, art_selector)
      end

    art_crop_url = selected_printing&.dig("image_uris", "art_crop")
    return art_crop_url unless blank?(art_crop_url)

    warn "Could not find selected art for #{card_info["name"]} using '#{art_selector}'. Using default art."
    nil
  rescue StandardError => e
    warn "Could not find selected art for #{card_info["name"]} using '#{art_selector}': #{e.message}. Using default art."
    nil
  end

  def printing_from_scryfall_url(art_selector)
    url_parts = Scryfall::Cards.parse_scryfall_card_url(art_selector)
    return nil if url_parts.nil?

    Scryfall::Cards.get_by_set_and_number(url_parts[:set_code], url_parts[:collector_number])
  end

  def printing_from_set_code(card_info, set_code)
    prints_search_uri = card_info["prints_search_uri"]
    return nil if blank?(prints_search_uri)

    Scryfall::Cards.get_print_from_uri(prints_search_uri, set_code)
  end

  # Horizontal point of the art (0 = left edge, 100 = right edge) to keep
  # centered when the art is cropped; nil keeps the default (centered).
  def parse_art_focus(card_name, value)
    return nil if blank?(value)

    percent = Float(value, exception: false)
    return percent / 100.0 if percent&.between?(0, 100)

    warn "Ignoring art focus '#{value}' for '#{card_name}': expected a number from 0 to 100."
    nil
  end

  def csv_value(row, column)
    value = row[column]
    return nil if value.nil?

    value.strip
  end

  def blank?(value)
    value.nil? || value.empty?
  end

  def log(message)
    $stdout.puts(message)
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    TokenCreator.run(ARGV)
  rescue TokenCreator::UsageError => e
    abort e.message
  end
end
