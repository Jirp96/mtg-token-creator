require "fileutils"
require "vips"

require_relative "layout"
require_relative "vips_helpers"
require_relative "art_downloader"
require_relative "frame_renderer"
require_relative "mana_symbol_renderer"
require_relative "title_section_renderer"
require_relative "rules_text_fitter"
require_relative "second_face_renderer"

module ImageGeneration
  include Layout
  extend VipsHelpers

  OUTPUT_DIR = "output".freeze

  def self.generate(card)
    palette = FRAME_PALETTES.fetch(card.frame_color, FRAME_PALETTES["C"])

    image = load_template
    image = image.composite(frame_renderer.render(palette), :over)
    image = add_art(image, card) unless card.saga?
    image = add_title(image, card.name, card.mana_cost)
    image = add_bar_text(image, card.type, TYPE_BAR_Y, TYPE_FONT_SIZE)
    image = add_oracle_section(image, card, palette)
    image = add_stat_line(image, card.stat_line)

    FileUtils.mkdir_p(OUTPUT_DIR)
    image.flatten(background: [255, 255, 255])
         .write_to_file("#{OUTPUT_DIR}/#{card.processed_name}.jpg", Q: 90, strip: true, interlace: false)
  end

  def self.add_art(image, card)
    art_data = ArtDownloader.fetch(card.art_crop_url)
    return image if art_data.nil?

    add_image(image, art_data, CARD_ART_X, CARD_ART_Y)
  end

  def self.load_template
    template = Vips::Image.new_from_file(CARD_TEMPLATE_FILE_NAME, access: :sequential)
    template = template.bandjoin(255) if template.bands == 3
    template.copy(interpretation: :srgb)
  end

  def self.add_title(image, name, mana_cost)
    width = BAR_WIDTH - (BAR_TEXT_PADDING * 2)
    line = TitleSectionRenderer.new(width: width, symbols: mana_symbols).render(card_name: name, mana_cost: mana_cost)
    image.composite(line, :over, x: BAR_X + BAR_TEXT_PADDING, y: TITLE_BAR_Y + vertical_center(BAR_HEIGHT, line.height))
  end

  # Single-line Beleren text, left aligned and vertically centered in a bar.
  def self.add_bar_text(image, text, bar_y, font_size)
    layer = fit_width(text_layer(text.to_s, "#{TITLE_FONT_FAMILY} #{font_size}"), BAR_WIDTH - (BAR_TEXT_PADDING * 2))
    image.composite(layer, :over, x: BAR_X + BAR_TEXT_PADDING, y: bar_y + vertical_center(BAR_HEIGHT, layer.height))
  end

  def self.add_stat_line(image, stat_line)
    layer = text_layer(stat_line, "#{TITLE_FONT_FAMILY} #{PT_FONT_SIZE}")
    image.composite(layer, :over,
                    x: PT_BOX_X + vertical_center(PT_BOX_WIDTH, layer.width),
                    y: PT_BOX_Y + vertical_center(PT_BOX_HEIGHT, layer.height))
  end

  # Oracle text, plus the second-face box for prepared double-faced tokens.
  def self.add_oracle_section(image, card, palette)
    inner_x = TEXT_BOX_X + TEXT_BOX_PADDING_X
    inner_w = TEXT_BOX_WIDTH - (TEXT_BOX_PADDING_X * 2)
    return add_oracle_text(image, card.oracle_text, inner_x, inner_w) unless card.second_face

    main_w = inner_w - SECOND_FACE_BOX_WIDTH - SECOND_FACE_BOX_GAP
    image = add_oracle_text(image, card.oracle_text, inner_x, main_w)

    # The box sits in the right column, so it must end above the P/T box.
    box_h = PT_BOX_Y - PT_BOX_CLEARANCE - (TEXT_BOX_Y + TEXT_BOX_PADDING_Y)
    box = second_face_renderer.render(card.second_face, SECOND_FACE_BOX_WIDTH, box_h, palette)
    image.composite(box, :over, x: inner_x + main_w + SECOND_FACE_BOX_GAP, y: TEXT_BOX_Y + TEXT_BOX_PADDING_Y)
  end

  def self.add_oracle_text(image, text, x, width)
    return image if text.to_s.strip.empty?

    layer, y = rules_text_fitter.fit(text, x, width)
    image.composite(layer, :over, x: x, y: y)
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

  # Renderers are reused across cards; their caches depend only on fonts.
  def self.rules_text_fitter
    @rules_text_fitter ||= RulesTextFitter.new(mana_symbols)
  end

  def self.mana_symbols
    @mana_symbols ||= ManaSymbolRenderer.new
  end

  def self.frame_renderer
    @frame_renderer ||= FrameRenderer.new
  end

  def self.second_face_renderer
    @second_face_renderer ||= SecondFaceRenderer.new
  end
end
