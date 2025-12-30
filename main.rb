require "csv"

require_relative "lib/scryfall"

NAME_COLUMN = 0
SCRYFALL_URL = ""

def main()
  raise StandardError unless ARGV.length > 0 #TODO: Custom error

  fileName = ARGV[0]

  cards = []

  CSV.foreach(fileName) do |row|
    cardName = row[NAME_COLUMN]

    cardApiResponse = Scryfall::Cards.get(cardName)

    cardData = Scryfall::Card.new(cardApiResponse.parse)

    cards.append(cardData)
  end

  #TODO: Get card's information from Scryfall API
end

main()