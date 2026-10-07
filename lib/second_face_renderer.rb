require "vips"

require_relative "vips_helpers"
require_relative "title_section_renderer"
require_relative "oracle_text_renderer"

# Renders the back face of a "prepared" token as an inset mini-card inside the
# rules-text box: name + cost, type line, and oracle text.
class SecondFaceRenderer
  include VipsHelpers

  def render(second_face, width, height, palette)
    pad     = SECOND_FACE_BOX_PADDING
    x_start = SECOND_FACE_BORDER + pad
    inner_w = width - (x_start * 2)

    bg = background(width, height, palette)
    y  = SECOND_FACE_BORDER + pad

    [title_layer(second_face, inner_w), type_layer(second_face, inner_w)].each do |layer|
      bg = bg.composite(layer, :over, x: x_start, y: y)
      y += layer.height + pad
      bg = draw_separator(bg, x_start, y, inner_w, palette)
      y += SECOND_FACE_SEPARATOR_H + pad
    end

    oracle = oracle_layer(second_face["oracle_text"].to_s, inner_w, height - y - pad)
    oracle.nil? ? bg : bg.composite(oracle, :over, x: x_start, y: y)
  end

  private

  def title_layer(second_face, width)
    TitleSectionRenderer.new(width: width, font_size: SECOND_FACE_NAME_SIZE, pip_diameter: SECOND_FACE_PIP_DIAMETER)
                        .render(card_name: second_face["name"].to_s, mana_cost: second_face["mana_cost"])
  end

  def type_layer(second_face, width)
    fit_width(text_layer(second_face["type_line"].to_s, "#{TITLE_FONT_FAMILY} #{SECOND_FACE_TYPE_SIZE}"), width)
  end

  def oracle_layer(text, width, max_height)
    return nil if text.strip.empty?

    layer = nil
    SECOND_FACE_ORACLE_SIZES.each do |size|
      layer = OracleTextRenderer.new(font_size: size).render(text, width)
      break if layer.height <= max_height
    end
    layer
  end

  def background(width, height, palette)
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}">
        <rect x="#{SECOND_FACE_BORDER / 2.0}" y="#{SECOND_FACE_BORDER / 2.0}"
              width="#{width - SECOND_FACE_BORDER}" height="#{height - SECOND_FACE_BORDER}" rx="18"
              fill="#{svg_color(shade(palette[:box], 0.94))}" stroke="#{svg_color(palette[:edge])}"
              stroke-width="#{SECOND_FACE_BORDER}"/>
      </svg>
    SVG
    Vips::Image.svgload_buffer(svg)
  end

  def draw_separator(image, x, y, width, palette)
    sep = Vips::Image.black(width, SECOND_FACE_SEPARATOR_H)
                     .new_from_image([*palette[:edge], 255])
                     .copy(interpretation: :srgb)
    image.composite(sep, :over, x: x, y: y)
  end
end
