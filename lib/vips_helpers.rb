require "vips"

require_relative "layout"

# Low-level vips compositing primitives shared across the renderers. Mixed in
# with `include` (instance methods) or `extend` (module-level helpers).
module VipsHelpers
  include Layout

  # A fully transparent RGBA canvas.
  def transparent_layer(width, height)
    Vips::Image.black(width, height).new_from_image([0, 0, 0, 0]).copy(interpretation: :srgb)
  end

  # Render `text` in `font` to an RGBA layer of black glyphs on transparent.
  def text_layer(text, font, font_file = nil)
    options = { font: font }
    options[:fontfile] = font_file unless font_file.nil?

    mask = Vips::Image.text(text, **options).extract_band(0)
    colorize_mask(mask, TEXT_BLACK)
  end

  # Composite black `text` onto `image` at (x, y), wrapped to `width`.
  def add_text(image, text, width, x, y, font = "Sans Bold 98", font_file = nil)
    options = { font: font, width: width, align: :low }
    options[:fontfile] = font_file unless font_file.nil?

    mask = Vips::Image.text(text, **options).extract_band(0)
    glyphs = image.new_from_image(TEXT_BLACK).crop(0, 0, mask.width, mask.height).bandjoin(mask)

    image.composite(glyphs, :over, x: x, y: y)
  end

  def vertical_center(container_h, element_h)
    (container_h - element_h) / 2
  end

  private

  # Build an RGBA layer of solid `color` shaped by a single-band alpha `mask`.
  def colorize_mask(mask, color)
    mask.new_from_image(color).bandjoin(mask).copy(interpretation: :srgb)
  end
end
