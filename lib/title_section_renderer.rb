require_relative "vips_helpers"
require_relative "mana_symbol_renderer"

# Renders a card name (left) and its mana cost pips (right) on a transparent
# strip, shrinking the name if it would collide with the cost.
class TitleSectionRenderer
  include VipsHelpers

  DEFAULT_GAP = 40

  def initialize(width:, font_size: TITLE_FONT_SIZE, pip_diameter: TITLE_PIP_DIAMETER, gap: DEFAULT_GAP, symbols: ManaSymbolRenderer.new)
    @width        = width
    @font         = "#{TITLE_FONT_FAMILY} #{font_size}"
    @pip_diameter = pip_diameter
    @gap          = gap
    @symbols      = symbols
  end

  def render(card_name:, mana_cost:)
    pips_img = cost_layer(mana_cost)
    pips_x   = @width - (pips_img&.width || 0)

    name_img = fit_width(text_layer(card_name.to_s, @font), pips_x - @gap)

    height = [name_img.height, pips_img&.height || 0].max
    strip = transparent_layer(@width, height)
    strip = strip.composite(name_img, :over, x: 0, y: vertical_center(height, name_img.height))
    return strip if pips_img.nil?

    strip.composite(pips_img, :over, x: pips_x, y: vertical_center(height, pips_img.height))
  end

  private

  def cost_layer(mana_cost)
    pips = ManaSymbolRenderer.parse_cost(mana_cost).map { |code| @symbols.render(code, @pip_diameter, shadow: true) }
    return nil if pips.empty?

    width = pips.sum(&:width) + (TITLE_PIP_GAP * (pips.length - 1))
    layer = transparent_layer(width, pips.map(&:height).max)
    x = 0
    pips.each do |pip|
      layer = layer.composite(pip, :over, x: x, y: 0)
      x += pip.width + TITLE_PIP_GAP
    end
    layer
  end
end
