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
    palette = FRAME_PALETTES.fetch(card.frame_color)
    geometry, rules_text = layout_rules_text(card)

    image = frame_with_art(card, palette, geometry)
    image = add_title(image, card.name, card.mana_cost)
    image = add_bar_text(image, card.type, geometry.type_bar_y, TYPE_FONT_SIZE)
    image = image.composite(rules_text[:layer], :over, x: rules_text[:x], y: rules_text[:y]) if rules_text
    image = add_second_face(image, card.second_face, palette, geometry) if card.second_face
    image = add_stat_line(image, card.stat_line)
    image = add_footer(image, card.footer)

    FileUtils.mkdir_p(OUTPUT_DIR)
    image.flatten(background: [255, 255, 255])
         .write_to_file("#{OUTPUT_DIR}/#{card.processed_name}.jpg", Q: 90, strip: true, interlace: false)
  end

  # Frame background, then the art, then the bars that overlap the art.
  def self.frame_with_art(card, palette, geometry)
    background, bars = frame_renderer.render(palette, geometry)
    image = load_template.composite(background, :over)
    image = add_art(image, card, geometry) unless card.saga?
    image.composite(bars, :over)
  end

  def self.add_art(image, card, geometry)
    art_data = ArtDownloader.fetch(card.art_crop_url)
    return image if art_data.nil?

    add_image(image, art_data, CARD_ART_X, CARD_ART_Y, CARD_ART_WIDTH, geometry.art_height, focus: card.art_focus)
  end

  def self.load_template
    template = Vips::Image.new_from_file(CARD_TEMPLATE_FILE_NAME, access: :sequential)
    template = template.bandjoin(255) if template.bands == 3
    template.copy(interpretation: :srgb)
  end

  def self.add_title(image, name, mana_cost)
    width = BAR_WIDTH - (BAR_TEXT_PADDING * 2)
    line = TitleSectionRenderer.new(width: width, align: :center, symbols: mana_symbols)
                               .render(card_name: name, mana_cost: mana_cost)
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

  # Collector-line style credit on the bottom black strip.
  def self.add_footer(image, text)
    layer = text_layer(text, "#{TITLE_FONT_FAMILY} #{FOOTER_FONT_SIZE}", TEXT_WHITE)
    image.composite(layer, :over, x: FOOTER_X, y: FOOTER_CENTER_Y - (layer.height / 2))
  end

  # Picks the card geometry (art height) from how much rules text there is.
  # Returns [geometry, rules_text], rules_text being { layer:, x:, y: } or nil.
  def self.layout_rules_text(card)
    geometries = TYPE_BAR_Y_OPTIONS.map { TokenGeometry.new(type_bar_y: it) }
    # Prepared tokens need the roomiest box to fit the second face beside the text.
    geometries = [geometries.last] if card.second_face
    return [geometries.first, nil] if card.oracle_text.to_s.strip.empty?

    x = TEXT_BOX_X + TEXT_BOX_PADDING_X
    width = TEXT_BOX_WIDTH - (TEXT_BOX_PADDING_X * 2)
    width -= SECOND_FACE_BOX_WIDTH + SECOND_FACE_BOX_GAP if card.second_face

    geometry, layer, y = rules_text_fitter.fit(card.oracle_text, x, width, geometries)
    [geometry, { layer: layer, x: x, y: y }]
  end

  # The second face sits in the right column, so it must end above the P/T box.
  def self.add_second_face(image, second_face, palette, geometry)
    y = geometry.text_box_y + TEXT_BOX_PADDING_Y
    box = second_face_renderer.render(second_face, SECOND_FACE_BOX_WIDTH, PT_BOX_Y - PT_BOX_CLEARANCE - y, palette)
    image.composite(box, :over, x: TEXT_BOX_X + TEXT_BOX_WIDTH - TEXT_BOX_PADDING_X - SECOND_FACE_BOX_WIDTH, y: y)
  end

  # Scale `image_buffer` to cover a width x height window and crop it, keeping
  # the horizontal `focus` (0..1 of the art's width, nil = center) in the middle.
  def self.add_image(image, image_buffer, x, y, width, height, focus: nil)
    art = load_art(image_buffer)
    art = art.resize([width.to_f / art.width, height.to_f / art.height].max)

    crop_x = ((art.width * (focus || 0.5)) - (width / 2.0)).round.clamp(0, art.width - width)
    crop_y = [(art.height - height) / 2, 0].max
    art = art.crop(crop_x, crop_y, width, height)

    image.composite(art, :over, x: x, y: y)
  end

  def self.load_art(image_buffer)
    art = Vips::Image.new_from_buffer(image_buffer, "", access: :sequential)
    art = art.colourspace(:srgb) if art.interpretation != :srgb
    art = art.bandjoin(255) if art.bands == 3
    art.copy(xres: 300.0 / 25.4, yres: 300.0 / 25.4)
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
