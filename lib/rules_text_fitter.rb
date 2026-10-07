require_relative "vips_helpers"
require_relative "oracle_text_renderer"

# Picks the largest oracle font size whose text fits the rules-text box, with
# no ink running into the P/T box, and centers it vertically like printed cards.
class RulesTextFitter
  include VipsHelpers

  def initialize(symbols)
    @symbols   = symbols
    @renderers = {}
  end

  # Returns the rendered layer and the card y at which to place it.
  def fit(text, x, width)
    top    = TEXT_BOX_Y + TEXT_BOX_PADDING_Y
    height = TEXT_BOX_HEIGHT - (TEXT_BOX_PADDING_Y * 2)
    layer = y = nil

    ORACLE_FONT_SIZES.each do |size|
      layer = renderer(size).render(text, width)
      y = top + [vertical_center(height, layer.height), 0].max
      break if layer.height <= height && !hits_pt_box?(layer, x, y)
    end

    [layer, y]
  end

  private

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
