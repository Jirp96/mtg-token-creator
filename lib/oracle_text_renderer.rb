require "vips"

require_relative "vips_helpers"

# Renders MTG oracle text with inline mana symbols, wrapping to a pixel width.
# Glyph/baseline metrics depend only on the fonts, so they are memoized per
# instance (state ownership is explicit, unlike the previous module-level cache).
class OracleTextRenderer
  include VipsHelpers

  # A mana symbol like {2}{W}, a run of whitespace, or a plain word.
  TOKEN_PATTERN = /\{[^}]+\}|\s+|[^\s{]+/

  # Render `text` to an RGBA layer no wider than `width`.
  def render(text, width)
    lines = wrapped_oracle_lines(text.to_s, width)
    total_height = lines.sum { |line| line[:height] } + (ORACLE_LINE_GAP * [lines.length - 1, 0].max)
    total_height = default_oracle_line_height if total_height.zero?
    canvas = transparent_layer(width, total_height)

    y = 0
    lines.each do |line|
      x = 0

      line[:items].each do |item|
        x += item[:space_before]
        item_image = leading_symbol?(item, x) ? remove_leading_symbol_padding(item[:image]) : item[:image]
        canvas = canvas.insert(item_image, x, y)
        x += item_image.width
      end

      y += line[:height] + ORACLE_LINE_GAP
    end

    canvas
  end

  private

  def leading_symbol?(item, x)
    item[:symbol] && x.zero?
  end

  def remove_leading_symbol_padding(symbol_layer)
    symbol_layer.crop(
      ORACLE_SYMBOL_HORIZONTAL_PADDING,
      0,
      symbol_layer.width - ORACLE_SYMBOL_HORIZONTAL_PADDING,
      symbol_layer.height
    )
  end

  def wrapped_oracle_lines(text, width)
    text.split("\n", -1).flat_map { |paragraph| wrap_paragraph(paragraph, width) }
  end

  # Greedily pack a single paragraph's tokens into lines no wider than `width`.
  def wrap_paragraph(paragraph, width)
    lines = []
    items = []
    line_width = 0
    line_height = default_oracle_line_height
    pending_space = false

    paragraph.scan(TOKEN_PATTERN).each do |token|
      if token.match?(/\A\s+\z/)
        pending_space = true unless items.empty?
        next
      end

      image = oracle_token_image(token)
      space = pending_space && !items.empty? ? oracle_space_width : 0

      if line_width.positive? && line_width + space + image.width > width
        lines << { items: items, height: line_height }
        items = []
        line_width = 0
        line_height = default_oracle_line_height
        space = 0
      end

      items << { image: image, space_before: space, symbol: oracle_symbol_token?(token) }
      line_width += space + image.width
      line_height = [line_height, image.height].max
      pending_space = false
    end

    lines << { items: items, height: line_height }
    lines
  end

  def oracle_token_image(token)
    if oracle_symbol_token?(token)
      symbol_text = token[1...-1].downcase.delete("/")
      padded_symbol_layer(text_layer(symbol_text, ORACLE_SYMBOL_FONT, ORACLE_SYMBOL_FONT_FILE))
    else
      oracle_text_layer(token)
    end
  end

  def oracle_symbol_token?(token)
    token.start_with?("{") && token.end_with?("}")
  end

  def padded_symbol_layer(symbol_layer)
    padded_layer = transparent_layer(
      symbol_layer.width + (ORACLE_SYMBOL_HORIZONTAL_PADDING * 2),
      default_oracle_line_height
    )
    symbol_y = oracle_text_visible_bottom - symbol_layer.height + ORACLE_SYMBOL_BASELINE_ADJUST
    symbol_y = [[symbol_y, 0].max, default_oracle_line_height - symbol_layer.height].min

    padded_layer.insert(symbol_layer, ORACLE_SYMBOL_HORIZONTAL_PADDING, symbol_y)
  end

  def oracle_text_layer(text)
    prefixed_text = "#{ORACLE_TEXT_BASELINE_PREFIX}#{text}"
    full_text = text_layer(prefixed_text, ORACLE_TEXT_FONT)
    prefix_width = oracle_baseline_prefix_width
    token_layer = full_text.crop(prefix_width, 0, full_text.width - prefix_width, full_text.height)
    normalize_oracle_layer(trim_oracle_layer_horizontally(token_layer))
  end

  def trim_oracle_layer_horizontally(layer)
    left, _top, width, _height = layer.extract_band(3).find_trim(background: 0)
    return layer if width.zero?

    layer.crop(left, 0, width, layer.height)
  end

  def normalize_oracle_layer(layer)
    return layer if layer.height == default_oracle_line_height
    return layer if layer.height > default_oracle_line_height

    transparent_layer(layer.width, default_oracle_line_height).insert(
      layer,
      0,
      default_oracle_line_height - layer.height
    )
  end

  # --- Memoized font metrics -------------------------------------------------

  def oracle_baseline_prefix_width
    @oracle_baseline_prefix_width ||= Vips::Image.text(ORACLE_TEXT_BASELINE_PREFIX, font: ORACLE_TEXT_FONT).width
  end

  def oracle_space_width
    @oracle_space_width ||= Vips::Image.text("n n", font: ORACLE_TEXT_FONT).width - Vips::Image.text("nn", font: ORACLE_TEXT_FONT).width
  end

  def oracle_text_visible_bottom
    @oracle_text_visible_bottom ||= begin
      mask = Vips::Image.text(ORACLE_TEXT_METRIC_SAMPLE, font: ORACLE_TEXT_FONT).extract_band(0)
      _left, top, _width, height = mask.find_trim(background: 0)
      top + height
    end
  end

  def default_oracle_line_height
    @default_oracle_line_height ||= Vips::Image.text(ORACLE_TEXT_METRIC_SAMPLE, font: ORACLE_TEXT_FONT).height
  end
end
