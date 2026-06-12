require_relative "vips_helpers"

class TitleSectionRenderer
  include VipsHelpers

  DEFAULT_PADDING = 150
  DEFAULT_GAP     = 80

  def initialize(
    width: 2200,
    font: "Cinzel",
    font_size: 96,
    padding: DEFAULT_PADDING,
    gap: DEFAULT_GAP,
    pips_font: "Beleren Small Caps",
    pips_font_file: nil
  )
    @width     = width
    @font      = font
    @font_size = font_size
    @padding   = padding
    @gap       = gap
    @pips_font = pips_font
    @pips_font_file = pips_font_file
  end

  def render(card_name:, pips_text:)
    name_img = render_text(card_name, @font_size)
    pips_img = render_text_custom_font(pips_text, @pips_font, @pips_font_file)

    name_img = ensure_rgba(name_img).invert
    pips_img = ensure_rgba(pips_img).invert

    # Compute fixed pip position (right anchored)
    pips_x = @width - @padding - pips_img.width

    # Calculate max width available for name
    max_name_width = pips_x - @padding - @gap

    if name_img.width > max_name_width
      scale = max_name_width.to_f / name_img.width
      name_img = name_img.resize(scale)
    end

    height = [name_img.height, pips_img.height].max

    title_bar = transparent_canvas(@width, height)

    name_x = @padding
    name_y = vertical_center(height, name_img.height)

    pips_y = vertical_center(height, pips_img.height)

    title_bar = title_bar.insert(name_img, name_x, name_y)
    title_bar = title_bar.insert(pips_img, pips_x, pips_y)

    title_bar
  end

  private

  def render_text(text, size)
    Vips::Image.text(
      text,
      font: "#{@font} #{size}"
    )
  end

  def render_text_custom_font(text, font, font_file)
    Vips::Image.text(
      text,
      font: "#{font}",
      fontfile: font_file
    )
  end

  def ensure_rgba(img)
    img.extract_band(0)
  end

  def transparent_canvas(width, height)
    Vips::Image.black(width, height).new_from_image([255, 255, 255])
  end
end
