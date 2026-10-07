require "vips"

require_relative "layout"

# Low-level vips compositing primitives shared across the renderers. Mixed in
# with `include` (instance methods) or `extend` (module-level helpers).
module VipsHelpers
  include Layout

  # Make the bundled font files visible to Pango by family name. Passing a
  # `fontfile` to vips registers it with fontconfig for the whole process.
  def self.register_fonts
    @register_fonts ||= FONT_FILES.each_value do |path|
      Vips::Image.text(".", fontfile: path) if File.exist?(path)
    end
  end

  # A fully transparent RGBA canvas.
  def transparent_layer(width, height)
    Vips::Image.black(width, height).new_from_image([0, 0, 0, 0]).copy(interpretation: :srgb)
  end

  # Render `text` in `font` to an RGBA layer of `color` glyphs on transparent.
  def text_layer(text, font, color = TEXT_BLACK, **)
    VipsHelpers.register_fonts
    mask = Vips::Image.text(text, font: font, **).extract_band(0)
    colorize_mask(mask, color)
  end

  # Shrink `layer` proportionally so it is no wider than `max_width`.
  def fit_width(layer, max_width)
    return layer if layer.width <= max_width

    layer.resize(max_width.to_f / layer.width)
  end

  def vertical_center(container_h, element_h)
    (container_h - element_h) / 2
  end

  def svg_color(rgb)
    r, g, b = rgb.map { |c| c.clamp(0, 255).round }
    format("#%<r>02x%<g>02x%<b>02x", r: r, g: g, b: b)
  end

  # Scale an RGB color towards black (factor < 1) or white (factor > 1).
  def shade(rgb, factor)
    if factor <= 1
      rgb.map { |c| c * factor }
    else
      rgb.map { |c| c + ((255 - c) * (factor - 1)) }
    end
  end

  private

  # Build an RGBA layer of solid `color` shaped by a single-band alpha `mask`.
  def colorize_mask(mask, color)
    mask.new_from_image(color).bandjoin(mask).copy(interpretation: :srgb)
  end
end
