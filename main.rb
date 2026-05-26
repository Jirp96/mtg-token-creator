#!/usr/bin/ruby
require "csv"

require_relative "lib/scryfall"
require_relative "lib/image_generation"
require_relative "lib/pdf_generation"

NAME_COLUMN = 0
ART_SELECTOR_COLUMN = 1
SCRYFALL_URL = ""
OUTPUT_IMAGES_PATH = "./output"

def csv_value(row, column)
  value = row[column]
  return nil if value.nil?

  value.strip
end

def resolve_art_crop_url(card_info, art_selector)
  return nil if art_selector.nil? || art_selector.empty?

  selected_printing = if Scryfall::Cards.scryfall_card_url?(art_selector)
                        printing_from_scryfall_url(art_selector)
                      else
                        printing_from_set_code(card_info, art_selector)
                      end

  art_crop_url = selected_printing&.dig("image_uris", "art_crop")
  return art_crop_url unless art_crop_url.nil? || art_crop_url.empty?

  warn "Could not find selected art for #{card_info["name"]} using '#{art_selector}'. Using default art."
  nil
rescue StandardError => error
  warn "Could not find selected art for #{card_info["name"]} using '#{art_selector}': #{error.message}. Using default art."
  nil
end

def printing_from_scryfall_url(art_selector)
  url_parts = Scryfall::Cards.parse_scryfall_card_url(art_selector)
  return nil if url_parts.nil?

  Scryfall::Cards.get_by_set_and_number(
    url_parts[:set_code],
    url_parts[:collector_number]
  )
end

def printing_from_set_code(card_info, set_code)
  prints_search_uri = card_info["prints_search_uri"]
  return nil if prints_search_uri.nil? || prints_search_uri.empty?

  Scryfall::Cards.get_print_from_uri(prints_search_uri, set_code)
end

def main()
  raise StandardError unless ARGV.length > 0 #TODO: Custom error

  fileName = ARGV[0]

  cards = []

  CSV.foreach(fileName) do |row|
    cardName = csv_value(row, NAME_COLUMN)
    next if cardName.nil? || cardName.empty?

    artSelector = csv_value(row, ART_SELECTOR_COLUMN)
    cardApiResponse = Scryfall::Cards.get(cardName)
    cardInfo = cardApiResponse.parse
    artCropUrl = resolve_art_crop_url(cardInfo, artSelector)

    cardData = Scryfall::Card.new(cardInfo, 4, 4, artCropUrl)

    cards.append(cardData)
  end

  p "Generating images"

  cards.each do |card|
    ImageGeneration.generate(card)
  end

  p "Generating pdf"

  #Create PDF with cards ready for print
  PdfGeneration.generate(OUTPUT_IMAGES_PATH, "pdf_sheet")

  p "Deleting temporary images"
  # Delete temporary files
  Dir.glob("#{OUTPUT_IMAGES_PATH}/*.jpg").each do |file|
    File.delete(file)
  end

end

main()
