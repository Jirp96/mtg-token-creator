require "net/http"
require "uri"
require "vips"

require_relative "title_section_renderer"

CARD_TEMPLATE_FILE_NAME = "card_template.png"

ORACLE_TEXT_FONT = "Sans 90"
CARD_TYPES_FONT = "Sans Bold 80"
CARD_TEXT_SIZE          = 2200
CARD_TEXT_X_MARGIN      = 200
CARD_TITLE_POSITION     = 120
CARD_TYPES_POSITION     = 1900
CARD_STAT_LINE_X_POSITION = 2000
CARD_STAT_LINE_Y_POSITION = 3200
CARD_ORACLE_TEXT_POSITION = 2200
CARD_ART_SIZE = 2000
CARD_ART_X = 200
CARD_ART_Y = 300

CARD_PIPS_FONT            = "NDPMTG 150"
CARD_PIPS_X_MARGIN        = 1800
CARD_PIPS_POSITION        = 120

ART_BOX = {
  width: 2100,
  height: 3000
}

module ImageGeneration
  def self.generate(card)
    outFileName = card.processed_name

    template = Vips::Image.new_from_file(CARD_TEMPLATE_FILE_NAME, access: :sequential)

    # Ensure template is RGBA
    template = template.bandjoin(255) if template.bands == 3

    # Write Mana Cost with PIPs
    pips_to_print = card.raw_cost.downcase
    
    generatedCard = add_title(template, card.name, pips_to_print, CARD_TEXT_SIZE, CARD_TEXT_X_MARGIN, CARD_TITLE_POSITION, CARD_PIPS_FONT, "fonts/NDPMTG.ttf")

    # Write cropped card image
    if not card.is_saga 
      cardArtData = download_image(card.art_crop_url)
      generatedCard = add_image(generatedCard, cardArtData, CARD_ART_SIZE, CARD_ART_X, CARD_ART_Y)
    end    

    # Write card types
    generatedCard = add_text(generatedCard, card.type, CARD_TEXT_SIZE, CARD_TEXT_X_MARGIN, CARD_TYPES_POSITION, CARD_TYPES_FONT)

    # Write card oracle text
    generatedCard = add_text(generatedCard, card.oracle_text, CARD_TEXT_SIZE, CARD_TEXT_X_MARGIN, CARD_ORACLE_TEXT_POSITION, ORACLE_TEXT_FONT)

    # Write P/T
    generatedCard = add_text(generatedCard, card.stat_line, CARD_TEXT_SIZE, CARD_STAT_LINE_X_POSITION, CARD_STAT_LINE_Y_POSITION)

    # Write to disk
    generatedCard.write_to_file("output/#{outFileName}.jpg", Q: 85, strip: true, interlace: false)

  end

  private

  # Add text to an image
  # Takes into account size, color, position and font
  def self.add_text(image, text, width, x, y, font = "Sans Bold 98", fontFile = nil)
    # Create text mask
    mask = nil

    if fontFile.nil?
      mask = Vips::Image.text(
        text,
        font: font,
        width: width,
        align: :low
      )
    else
      mask = Vips::Image.text(
        text,
        font: font,
        width: width,
        align: :low,
        fontfile: fontFile
      )
    end
    

    # Force single-band mask (important!)
    mask = mask.extract_band(0)

    color_layer = image.new_from_image([0, 0, 0])
    text = color_layer.crop(0, 0, mask.width, mask.height)
    text = text.bandjoin(mask)

    # Composite
    image.composite(
      text,
      :over,
      x: x,
      y: y
    )
  end

  def self.add_image(image, imageBuffer, size, x, y)
    art = Vips::Image.new_from_buffer(
      imageBuffer,
      "",
      access: :sequential
    )

    if art.interpretation != :srgb
      art = art.colourspace(:srgb)
    end

    art = art.bandjoin(255) if art.bands == 3

    art = art.copy(
      xres: 300.0 / 25.4,
      yres: 300.0 / 25.4
    )

    scale = [
      ART_BOX[:width].to_f / art.width,
      ART_BOX[:height].to_f / art.height
    ].min

    art = art.resize(scale)


    image.composite(
      art,
      :over,
      x: x,
      y: y
    )
  end

  def self.add_title(image, title_text, pips_text, width, x, y, font = "Sans Bold 98", fontFile = nil)
    renderer = TitleSectionRenderer.new(pips_font: CARD_PIPS_FONT, pips_font_file: fontFile)

    line = renderer.render(
      card_name: title_text,
      pips_text: pips_text
    )

    image.composite(
      line,
      :over,
      x: x,
      y: y
    )

  end

  def self.download_image(image_url)
    uri = URI(image_url)
    Net::HTTP.get(uri)
  end
end