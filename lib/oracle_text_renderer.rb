require "vips"

require_relative "vips_helpers"
require_relative "mana_symbol_renderer"
require_relative "text_metrics"

# Renders MTG oracle text with inline mana symbols, wrapping to a pixel width.
# Reminder text (in parentheses) is set in italics, and paragraphs get extra
# spacing like on printed cards.
class OracleTextRenderer
  include VipsHelpers

  # A mana symbol like {2}{W}, a run of whitespace, or a plain word.
  TOKEN_PATTERN = /\{[^}]+\}|\s+|[^\s{]+/

  attr_reader :font_size

  def initialize(font_size: ORACLE_FONT_SIZES.first, symbols: ManaSymbolRenderer.new)
    @font_size       = font_size
    @font            = "#{ORACLE_FONT_FAMILY} #{font_size}"
    @symbols         = symbols
    @symbol_diameter = (font_size * ORACLE_SYMBOL_SCALE).round
    @line_gap        = (font_size * ORACLE_LINE_GAP_RATIO).round
    @paragraph_gap   = (font_size * ORACLE_PARAGRAPH_GAP_RATIO).round
    @metrics         = TextMetrics.new(@font)
  end

  # Render `text` to an RGBA layer no wider than `width`.
  def render(text, width)
    lines = wrapped_oracle_lines(text.to_s, width)
    total_height = lines.each_with_index.sum { |line, i| @metrics.line_height + (i.zero? ? 0 : gap_before(line)) }
    canvas = transparent_layer(width, [total_height, @metrics.line_height].max)

    y = 0
    lines.each_with_index do |line, i|
      y += gap_before(line) unless i.zero?
      canvas = draw_line(canvas, line[:items], y)
      y += @metrics.line_height
    end

    canvas
  end

  private

  # Consecutive words are rendered as a single run so Pango handles spacing
  # and kerning (important for italics, whose glyphs overhang their advance).
  def draw_line(canvas, items, y)
    x = 0
    items.chunk_while { |a, b| !a[:symbol] && !b[:symbol] }.each do |group|
      x += group.first[:space_before]
      layer =
        if group.first[:symbol]
          x.zero? ? remove_leading_symbol_padding(group.first[:image]) : group.first[:image]
        else
          oracle_text_layer(group.map { |item| item[:markup] }.join(" "))
        end
      canvas = canvas.composite(layer, :over, x: x, y: y)
      x += layer.width
    end
    canvas
  end

  def gap_before(line)
    line[:paragraph_start] ? @line_gap + @paragraph_gap : @line_gap
  end

  def remove_leading_symbol_padding(layer)
    layer.crop(ORACLE_SYMBOL_HORIZONTAL_PADDING, 0, layer.width - ORACLE_SYMBOL_HORIZONTAL_PADDING, layer.height)
  end

  def wrapped_oracle_lines(text, width)
    text.split("\n", -1).flat_map do |paragraph|
      lines = wrap_paragraph(paragraph, width)
      lines.first[:paragraph_start] = true
      lines
    end
  end

  # Greedily pack a single paragraph's tokens into lines no wider than `width`.
  def wrap_paragraph(paragraph, width)
    lines = []
    items = []
    line_width = 0
    pending_space = false
    italic = false

    paragraph.scan(TOKEN_PATTERN).each do |token|
      if token.match?(/\A\s+\z/)
        pending_space = true unless items.empty?
        next
      end

      italic ||= token.start_with?("(")
      item = oracle_item(token, italic)
      italic = false if token.include?(")")
      space = pending_space && !items.empty? ? @metrics.space_width : 0

      if line_width.positive? && line_width + space + item[:width] > width
        lines << { items: items }
        items = []
        line_width = 0
        space = 0
      end

      items << item.merge(space_before: space)
      line_width += space + item[:width]
      pending_space = false
    end

    lines << { items: items }
    lines
  end

  def oracle_item(token, italic)
    if oracle_symbol_token?(token)
      image = padded_symbol_layer(@symbols.render(token[1...-1], @symbol_diameter))
      { symbol: true, image: image, width: image.width }
    else
      markup = escape_markup(token)
      markup = "<i>#{markup}</i>" if italic
      { symbol: false, markup: markup, width: @metrics.advance_width(markup) }
    end
  end

  def oracle_symbol_token?(token)
    token.start_with?("{") && token.end_with?("}")
  end

  def escape_markup(text)
    text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  # Sit the symbol on the text baseline, dipping slightly below it.
  def padded_symbol_layer(symbol_layer)
    padded_layer = transparent_layer(symbol_layer.width + (ORACLE_SYMBOL_HORIZONTAL_PADDING * 2), @metrics.line_height)
    symbol_y = @metrics.baseline - symbol_layer.height + (symbol_layer.height * 0.1).round
    symbol_y = symbol_y.clamp(0, [@metrics.line_height - symbol_layer.height, 0].max)

    padded_layer.composite(symbol_layer, :over, x: ORACLE_SYMBOL_HORIZONTAL_PADDING, y: symbol_y)
  end

  # Render text with a fixed prefix so every run shares the same baseline,
  # then cut the prefix off again.
  def oracle_text_layer(markup)
    full_text = text_layer("#{ORACLE_TEXT_BASELINE_PREFIX}#{markup}", @font)
    token_layer = full_text.crop(@metrics.prefix_width, 0, full_text.width - @metrics.prefix_width, full_text.height)
    normalize_oracle_layer(trim_oracle_layer_horizontally(token_layer))
  end

  def trim_oracle_layer_horizontally(layer)
    left, _top, width, _height = layer.extract_band(3).find_trim(background: 0)
    return layer if width.zero?

    layer.crop(left, 0, width, layer.height)
  end

  def normalize_oracle_layer(layer)
    return layer if layer.height >= @metrics.line_height

    transparent_layer(layer.width, @metrics.line_height).insert(layer, 0, @metrics.line_height - layer.height)
  end
end
