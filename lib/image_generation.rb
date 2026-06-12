require "net/http"
require "uri"
require "vips"

require_relative "layout"
require_relative "vips_helpers"
require_relative "title_section_renderer"
require_relative "oracle_text_renderer"
require_relative "second_face_renderer"

# Orchestrates rendering a single card image onto the card template: title and
# mana pips, cropped art, type line, oracle text (delegated to
# OracleTextRenderer), the optional second-face box (delegated to
# SecondFaceRenderer), and the P/T stat line. Writes the result as a JPEG.
module ImageGeneration
  include Layout
  extend VipsHelpers

  def self.generate(card)
    image = load_template
    image = add_title(image, card.name, card.raw_cost.downcase, CARD_ART_WIDTH, CARD_TITLE_X, CARD_TITLE_POSITION, ORACLE_SYMBOL_FONT_FILE)

    image = add_image(image, download_image(card.art_crop_url), CARD_ART_X, CARD_ART_Y) unless card.saga?
    image = add_text(image, card.type, CARD_TEXT_SIZE, CARD_TEXT_X_MARGIN, CARD_TYPES_POSITION, CARD_TYPES_FONT)
    image = add_oracle_section(image, card)
    image = add_text(image, card.stat_line, CARD_TEXT_SIZE, CARD_STAT_LINE_X_POSITION, CARD_STAT_LINE_Y_POSITION)

    image.write_to_file("output/#{card.processed_name}.jpg", Q: 85, strip: true, interlace: false)
  end

  def self.load_template
    template = Vips::Image.new_from_file(CARD_TEMPLATE_FILE_NAME, access: :sequential)
    template = template.bandjoin(255) if template.bands == 3
    template
  end

  # Oracle text, plus the second-face box for prepared double-faced tokens.
  def self.add_oracle_section(image, card)
    return add_oracle_text(image, card.oracle_text, CARD_TEXT_SIZE, CARD_TEXT_X_MARGIN, CARD_ORACLE_TEXT_POSITION) unless card.second_face

    main_w = CARD_TEXT_SIZE - SECOND_FACE_BOX_WIDTH - SECOND_FACE_BOX_GAP
    image = add_oracle_text(image, card.oracle_text, main_w, CARD_TEXT_X_MARGIN, CARD_ORACLE_TEXT_POSITION)

    box = second_face_renderer.render(card.second_face, SECOND_FACE_BOX_WIDTH, SECOND_FACE_BOX_HEIGHT)
    image.composite(box, :over, x: CARD_TEXT_X_MARGIN + main_w + SECOND_FACE_BOX_GAP, y: CARD_ORACLE_TEXT_POSITION)
  end

  def self.add_oracle_text(image, text, width, x, y)
    image.composite(oracle_renderer.render(text, width), :over, x: x, y: y)
  end

  def self.add_title(image, title_text, pips_text, width, x, y, font_file = nil)
    renderer = TitleSectionRenderer.new(
      width: width,
      padding: 0,
      pips_font: CARD_PIPS_FONT,
      pips_font_file: font_file
    )

    line = renderer.render(card_name: title_text, pips_text: pips_text)
    image.composite(line, :over, x: x, y: y)
  end

  def self.add_image(image, image_buffer, x, y)
    art = Vips::Image.new_from_buffer(image_buffer, "", access: :sequential)
    art = art.colourspace(:srgb) if art.interpretation != :srgb
    art = art.bandjoin(255) if art.bands == 3
    art = art.copy(xres: 300.0 / 25.4, yres: 300.0 / 25.4)

    scale = [CARD_ART_WIDTH.to_f / art.width, CARD_ART_HEIGHT.to_f / art.height].max
    art = art.resize(scale)

    crop_x = [(art.width - CARD_ART_WIDTH) / 2, 0].max
    crop_y = [(art.height - CARD_ART_HEIGHT) / 2, 0].max
    art = art.crop(crop_x, crop_y, CARD_ART_WIDTH, CARD_ART_HEIGHT)

    image.composite(art, :over, x: x, y: y)
  end

  def self.download_image(image_url)
    Net::HTTP.get(URI(image_url))
  end

  # Reused across cards; the cached font metrics inside depend only on fonts.
  def self.oracle_renderer
    @oracle_renderer ||= OracleTextRenderer.new
  end

  def self.second_face_renderer
    @second_face_renderer ||= SecondFaceRenderer.new
  end
end
