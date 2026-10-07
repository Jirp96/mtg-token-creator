require "vips"

require_relative "vips_helpers"

# Renders a single mana symbol (e.g. "W", "2", "U/B", "T") as a colored circle
# with the NDPMTG glyph on top, like the pips printed on real cards.
class ManaSymbolRenderer
  include VipsHelpers

  GLYPH_HEIGHT_RATIO = 0.72
  GLYPH_WIDTH_RATIO  = 0.80
  SHADOW_RATIO       = 0.07

  # `shadow` adds the offset black drop shadow used for mana costs.
  def render(code, diameter, shadow: false)
    @cache ||= {}
    @cache[[code, diameter, shadow]] ||= build(code.to_s.upcase, diameter, shadow)
  end

  # Split a Scryfall cost string like "{2}{U}{B}" into ["2", "U", "B"].
  def self.parse_cost(mana_cost)
    mana_cost.to_s.scan(/\{([^}]+)\}/).flatten
  end

  private

  def build(code, diameter, shadow)
    offset = shadow ? (diameter * SHADOW_RATIO).round : 0
    disc = Vips::Image.svgload_buffer(disc_svg(code, diameter, offset))

    glyph = glyph_layer(code, diameter)
    glyph_x = offset + vertical_center(diameter, glyph.width)
    glyph_y = vertical_center(diameter, glyph.height)
    disc.composite(glyph, :over, x: glyph_x, y: glyph_y)
  end

  def disc_svg(code, diameter, offset)
    r = diameter / 2.0
    colors = code.split("/").filter_map { |part| MANA_COLORS[part] }
    fill = colors.length == 2 ? "url(#hybrid)" : svg_color(colors.first || MANA_GENERIC_COLOR)
    hybrid = ""
    if colors.length == 2
      hybrid = <<~SVG
        <linearGradient id="hybrid" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0.5" stop-color="#{svg_color(colors[0])}"/>
          <stop offset="0.5" stop-color="#{svg_color(colors[1])}"/>
        </linearGradient>
      SVG
    end
    shadow = offset.positive? ? %(<circle cx="#{r}" cy="#{r + offset}" r="#{r}" fill="#000"/>) : ""

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{diameter + offset}" height="#{diameter + offset}">
        <defs>#{hybrid}</defs>
        #{shadow}
        <circle cx="#{r + offset}" cy="#{r}" r="#{r}" fill="#{fill}"/>
      </svg>
    SVG
  end

  def glyph_layer(code, diameter)
    glyph = text_layer(code.downcase.delete("/"), MANA_FONT)
    scale = [diameter * GLYPH_HEIGHT_RATIO / glyph.height, diameter * GLYPH_WIDTH_RATIO / glyph.width].min
    glyph.resize(scale)
  end
end
