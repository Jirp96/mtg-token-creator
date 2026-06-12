require "vips"

require_relative "vips_helpers"
require_relative "scryfall/card"

# Renders the inset "second face" box used by prepared double-faced tokens:
# a bordered panel with name + mana cost, type line, and oracle text, separated
# by horizontal rules.
class SecondFaceRenderer
  # Horizontal room reserved for the mana cost to the right of the name.
  NAME_MANA_RESERVE = 150

  include VipsHelpers

  def render(second_face, width, height)
    pad     = SECOND_FACE_BOX_PADDING
    x_start = SECOND_FACE_BORDER + pad
    inner_w = width - x_start - pad

    bg = background(width, height)
    y  = SECOND_FACE_BORDER + pad

    name_text = second_face["name"] || ""
    bg = add_text(bg, name_text, inner_w - NAME_MANA_RESERVE, x_start, y, SECOND_FACE_NAME_FONT)
    bg = composite_mana_cost(bg, second_face["mana_cost"], width, pad, y)
    y  = advance(y, name_text, SECOND_FACE_NAME_FONT, pad)

    bg = draw_separator(bg, x_start, y, inner_w)
    y += SECOND_FACE_SEPARATOR_H + pad

    type_text = second_face["type_line"] || ""
    bg = add_text(bg, type_text, inner_w, x_start, y, SECOND_FACE_TYPE_FONT)
    y  = advance(y, type_text, SECOND_FACE_TYPE_FONT, pad)

    bg = draw_separator(bg, x_start, y, inner_w)
    y += SECOND_FACE_SEPARATOR_H + pad

    oracle_text = second_face["oracle_text"] || ""
    bg = add_text(bg, oracle_text, inner_w, x_start, y, SECOND_FACE_ORACLE_FONT) unless oracle_text.empty?

    bg
  end

  private

  # A border-colored panel with a slightly inset background fill.
  def background(width, height)
    inner = Vips::Image.black(width - (SECOND_FACE_BORDER * 2), height - (SECOND_FACE_BORDER * 2))
                       .new_from_image(SECOND_FACE_BG_COLOR)
                       .copy(interpretation: :srgb)

    Vips::Image.black(width, height)
               .new_from_image(SECOND_FACE_BORDER_COLOR)
               .copy(interpretation: :srgb)
               .composite(inner, :over, x: SECOND_FACE_BORDER, y: SECOND_FACE_BORDER)
  end

  def composite_mana_cost(image, mana_cost, width, pad, y)
    cost = Scryfall::Card.strip_mana_cost(mana_cost).downcase
    return image if cost.empty?

    pips = text_layer(cost, SECOND_FACE_PIPS_FONT, ORACLE_SYMBOL_FONT_FILE)
    image.composite(pips, :over, x: width - SECOND_FACE_BORDER - pad - pips.width, y: y)
  end

  # Move the y cursor past a line of `text` rendered in `font`, plus padding.
  def advance(y, text, font, pad)
    measured = text.empty? ? " " : text
    y + Vips::Image.text(measured, font: font).height + pad
  end

  def draw_separator(image, x, y, width)
    sep = Vips::Image.black(width, SECOND_FACE_SEPARATOR_H)
                     .new_from_image(SECOND_FACE_BORDER_COLOR)
                     .copy(interpretation: :srgb)
    image.composite(sep, :over, x: x, y: y)
  end
end
