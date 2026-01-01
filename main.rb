#!/usr/bin/ruby
require "csv"

require_relative "lib/scryfall"
require_relative "lib/image_generation"
require_relative "lib/pdf_generation"

NAME_COLUMN = 0
SCRYFALL_URL = ""
OUTPUT_IMAGES_PATH = "./output"

def main()
  raise StandardError unless ARGV.length > 0 #TODO: Custom error

  fileName = ARGV[0]

  cards = []

  CSV.foreach(fileName) do |row|
    cardName = row[NAME_COLUMN]

    cardApiResponse = Scryfall::Cards.get(cardName)

    cardData = Scryfall::Card.new(cardApiResponse.parse, 4, 4)

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
  Dir.glob("#{OUTPUT_IMAGES_PATH}/*.png").each do |file|
    File.delete(file)
  end

end

main()