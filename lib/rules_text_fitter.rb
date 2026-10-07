require_relative "vips_helpers"
require_relative "oracle_text_renderer"

# Lays out rules text: picks the tallest-art geometry whose text box holds the
# text at a comfortable size, then the largest font size that fits without ink
# running into the P/T box, centered vertically like printed cards.
class RulesTextFitter
  include VipsHelpers

  def initialize(symbols)
    @symbols   = symbols
    @renderers = {}
  end

  # `geometries` are Layout::TokenGeometry candidates, tallest art first. Every
  # one but the last must fit at ORACLE_PREFERRED_MIN_SIZE or larger; the last
  # takes any size, and as a last resort the smallest even if it overflows.
  # Returns [geometry, layer, y].
  def fit(text, x, width, geometries)
    layers = Hash.new { |cache, size| cache[size] = renderer(size).render(text, width) }

    geometries.each_with_index do |geometry, i|
      sizes = i == geometries.length - 1 ? ORACLE_FONT_SIZES : ORACLE_FONT_SIZES.select { it >= ORACLE_PREFERRED_MIN_SIZE }
      sizes.each do |size|
        y = place(layers[size], x, geometry)
        return [geometry, layers[size], y] if y
      end
    end

    [geometries.last, layers[ORACLE_FONT_SIZES.last], geometries.last.text_box_y + TEXT_BOX_PADDING_Y]
  end

  private

  # The y at which `layer` sits centered in the text box, or nil if it doesn't fit.
  def place(layer, x, geometry)
    height = geometry.text_box_height - (TEXT_BOX_PADDING_Y * 2)
    return nil if layer.height > height

    y = geometry.text_box_y + TEXT_BOX_PADDING_Y + vertical_center(height, layer.height)
    hits_pt_box?(layer, x, y) ? nil : y
  end

  def hits_pt_box?(layer, x, y)
    left = PT_BOX_X - PT_BOX_CLEARANCE - x
    top  = PT_BOX_Y - PT_BOX_CLEARANCE - y
    return false if left >= layer.width || top >= layer.height

    left = left.clamp(0, layer.width - 1)
    top  = top.clamp(0, layer.height - 1)
    layer.extract_band(3).crop(left, top, layer.width - left, layer.height - top).max.positive?
  end

  # Renderers cache font metrics, so reuse one per size.
  def renderer(size)
    @renderers[size] ||= OracleTextRenderer.new(font_size: size, symbols: @symbols)
  end
end
