require "net/http"
require "uri"
require "vips"

require_relative "title_section_renderer"

CARD_TEMPLATE_FILE_NAME = "card_template.png"

ORACLE_TEXT_FONT = "Sans 90"
ORACLE_SYMBOL_FONT = "NDPMTG 105"
ORACLE_SYMBOL_FONT_FILE = "fonts/NDPMTG.ttf"
ORACLE_LINE_GAP = 24
ORACLE_TEXT_BASELINE_PREFIX = "Ag "
ORACLE_TEXT_METRIC_SAMPLE = "#{ORACLE_TEXT_BASELINE_PREFIX}ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789,.:;()'/-"
ORACLE_SYMBOL_HORIZONTAL_PADDING = 10
ORACLE_SYMBOL_BASELINE_ADJUST = 0
CARD_TYPES_FONT = "Sans Bold 80"
CARD_TEXT_SIZE          = 2200
CARD_TEXT_X_MARGIN      = 200
CARD_TITLE_POSITION     = 120
CARD_TYPES_POSITION     = 1900
CARD_STAT_LINE_X_POSITION = 2000
CARD_STAT_LINE_Y_POSITION = 3200
CARD_ORACLE_TEXT_POSITION = 2200
CARD_ART_X = 200
CARD_ART_Y = 300
CARD_TITLE_X = CARD_ART_X

CARD_PIPS_FONT            = "NDPMTG 150"
CARD_PIPS_X_MARGIN        = 1800
CARD_PIPS_POSITION        = 120

# Scryfall art_crop images for regular cards use a 626x457 aspect ratio.
CARD_ART_WIDTH = 2100
CARD_ART_HEIGHT = (CARD_ART_WIDTH * 457.0 / 626).round

module ImageGeneration
  def self.generate(card)
    outFileName = card.processed_name

    template = Vips::Image.new_from_file(CARD_TEMPLATE_FILE_NAME, access: :sequential)

    # Ensure template is RGBA
    template = template.bandjoin(255) if template.bands == 3

    # Write Mana Cost with PIPs
    pips_to_print = card.raw_cost.downcase
    
    generatedCard = add_title(template, card.name, pips_to_print, CARD_ART_WIDTH, CARD_TITLE_X, CARD_TITLE_POSITION, CARD_PIPS_FONT, "fonts/NDPMTG.ttf")

    # Write cropped card image
    if not card.is_saga 
      cardArtData = download_image(card.art_crop_url)
      generatedCard = add_image(generatedCard, cardArtData, CARD_ART_X, CARD_ART_Y)
    end    

    # Write card types
    generatedCard = add_text(generatedCard, card.type, CARD_TEXT_SIZE, CARD_TEXT_X_MARGIN, CARD_TYPES_POSITION, CARD_TYPES_FONT)

    # Write card oracle text
    generatedCard = add_oracle_text(generatedCard, card.oracle_text, CARD_TEXT_SIZE, CARD_TEXT_X_MARGIN, CARD_ORACLE_TEXT_POSITION)

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

  def self.add_oracle_text(image, text, width, x, y)
    rendered_text = render_inline_oracle_text(text.to_s, width)

    image.composite(
      rendered_text,
      :over,
      x: x,
      y: y
    )
  end

  def self.render_inline_oracle_text(text, width)
    lines = wrapped_oracle_lines(text, width)
    total_height = lines.sum { |line| line[:height] } + (ORACLE_LINE_GAP * [lines.length - 1, 0].max)
    total_height = default_oracle_line_height if total_height.zero?
    canvas = transparent_layer(width, total_height)

    y = 0
    lines.each do |line|
      x = 0

      line[:items].each do |item|
        x += item[:space_before]
        item_image = leading_symbol?(item, x) ? remove_leading_symbol_padding(item[:image]) : item[:image]
        canvas = canvas.insert(item_image, x, y)
        x += item_image.width
      end

      y += line[:height] + ORACLE_LINE_GAP
    end

    canvas
  end

  def self.leading_symbol?(item, x)
    item[:symbol] && x.zero?
  end

  def self.remove_leading_symbol_padding(symbol_layer)
    symbol_layer.crop(
      ORACLE_SYMBOL_HORIZONTAL_PADDING,
      0,
      symbol_layer.width - ORACLE_SYMBOL_HORIZONTAL_PADDING,
      symbol_layer.height
    )
  end

  def self.wrapped_oracle_lines(text, width)
    lines = []

    text.split("\n", -1).each do |paragraph|
      current_items = []
      current_width = 0
      current_height = default_oracle_line_height
      pending_space = false

      paragraph.scan(/\{[^}]+\}|\s+|[^\s{]+/).each do |token|
        if token.match?(/\A\s+\z/)
          pending_space = true unless current_items.empty?
          next
        end

        item_image = oracle_token_image(token)
        space_before = current_items.empty? ? 0 : (pending_space ? oracle_space_width : 0)

        if current_width.positive? && current_width + space_before + item_image.width > width
          lines << { items: current_items, height: current_height }
          current_items = []
          current_width = 0
          current_height = default_oracle_line_height
          space_before = 0
        end

        current_items << {
          image: item_image,
          space_before: space_before,
          symbol: oracle_symbol_token?(token)
        }
        current_width += space_before + item_image.width
        current_height = [current_height, item_image.height].max
        pending_space = false
      end

      lines << { items: current_items, height: current_height }
    end

    lines
  end

  def self.oracle_token_image(token)
    if oracle_symbol_token?(token)
      symbol_text = token[1...-1].downcase.delete("/")
      padded_symbol_layer(text_layer(symbol_text, ORACLE_SYMBOL_FONT, ORACLE_SYMBOL_FONT_FILE))
    else
      oracle_text_layer(token)
    end
  end

  def self.oracle_symbol_token?(token)
    token.start_with?("{") && token.end_with?("}")
  end

  def self.padded_symbol_layer(symbol_layer)
    padded_layer = transparent_layer(
      symbol_layer.width + (ORACLE_SYMBOL_HORIZONTAL_PADDING * 2),
      default_oracle_line_height
    )
    symbol_y = oracle_text_visible_bottom - symbol_layer.height + ORACLE_SYMBOL_BASELINE_ADJUST
    symbol_y = [[symbol_y, 0].max, default_oracle_line_height - symbol_layer.height].min

    padded_layer.insert(symbol_layer, ORACLE_SYMBOL_HORIZONTAL_PADDING, symbol_y)
  end

  def self.oracle_text_layer(text)
    prefixed_text = "#{ORACLE_TEXT_BASELINE_PREFIX}#{text}"
    full_text = text_layer(prefixed_text, ORACLE_TEXT_FONT)
    prefix_width = oracle_baseline_prefix_width
    token_layer = full_text.crop(prefix_width, 0, full_text.width - prefix_width, full_text.height)
    normalize_oracle_layer(trim_oracle_layer_horizontally(token_layer))
  end

  def self.oracle_baseline_prefix_width
    @oracle_baseline_prefix_width ||= Vips::Image.text(ORACLE_TEXT_BASELINE_PREFIX, font: ORACLE_TEXT_FONT).width
  end

  def self.text_layer(text, font, font_file = nil)
    options = { font: font }
    options[:fontfile] = font_file unless font_file.nil?

    mask = Vips::Image.text(text, **options).extract_band(0)
    color_layer = mask.new_from_image([0, 0, 0])
    color_layer.bandjoin(mask).copy(interpretation: :srgb)
  end

  def self.trim_oracle_layer_horizontally(layer)
    left, _top, width, _height = layer.extract_band(3).find_trim(background: 0)
    return layer if width.zero?

    layer.crop(left, 0, width, layer.height)
  end

  def self.normalize_oracle_layer(layer)
    return layer if layer.height == default_oracle_line_height

    return layer if layer.height > default_oracle_line_height

    transparent_layer(layer.width, default_oracle_line_height).insert(
      layer,
      0,
      default_oracle_line_height - layer.height
    )
  end

  def self.oracle_space_width
    @oracle_space_width ||= Vips::Image.text("n n", font: ORACLE_TEXT_FONT).width - Vips::Image.text("nn", font: ORACLE_TEXT_FONT).width
  end

  def self.oracle_text_visible_bottom
    @oracle_text_visible_bottom ||= begin
      mask = Vips::Image.text(ORACLE_TEXT_METRIC_SAMPLE, font: ORACLE_TEXT_FONT).extract_band(0)
      _left, top, _width, height = mask.find_trim(background: 0)
      top + height
    end
  end

  def self.default_oracle_line_height
    @default_oracle_line_height ||= Vips::Image.text(ORACLE_TEXT_METRIC_SAMPLE, font: ORACLE_TEXT_FONT).height
  end

  def self.transparent_layer(width, height)
    Vips::Image.black(width, height).new_from_image([0, 0, 0, 0]).copy(interpretation: :srgb)
  end

  def self.vertical_center(container_h, element_h)
    (container_h - element_h) / 2
  end

  def self.add_image(image, imageBuffer, x, y)
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
      CARD_ART_WIDTH.to_f / art.width,
      CARD_ART_HEIGHT.to_f / art.height
    ].max

    art = art.resize(scale)
    crop_x = [(art.width - CARD_ART_WIDTH) / 2, 0].max
    crop_y = [(art.height - CARD_ART_HEIGHT) / 2, 0].max
    art = art.crop(crop_x, crop_y, CARD_ART_WIDTH, CARD_ART_HEIGHT)


    image.composite(
      art,
      :over,
      x: x,
      y: y
    )
  end

  def self.add_title(image, title_text, pips_text, width, x, y, font = "Sans Bold 98", fontFile = nil)
    renderer = TitleSectionRenderer.new(
      width: width,
      padding: 0,
      pips_font: CARD_PIPS_FONT,
      pips_font_file: fontFile
    )

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