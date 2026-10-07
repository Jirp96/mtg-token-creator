require "vips"

require_relative "vips_helpers"

# Memoized measurements of a single Pango font description. vips text output
# is cropped to the ink, so widths and heights are measured against fixed
# reference glyphs ("|" bars and ORACLE_TEXT_BASELINE_PREFIX).
class TextMetrics
  include Layout

  def initialize(font)
    @font  = font
    @cache = {}
  end

  def text_width(text)
    VipsHelpers.register_fonts
    Vips::Image.text(text, font: @font).width
  end

  # Typographic advance (not ink extent), measured between two "|" bars so
  # that wrapping matches how Pango spaces a whole run.
  def advance_width(markup)
    text_width("|#{markup}|") - bars_width
  end

  def prefix_width
    memo(:prefix_width) { text_width(ORACLE_TEXT_BASELINE_PREFIX) }
  end

  def space_width
    memo(:space_width) { advance_width(" ") }
  end

  def line_height
    memo(:line_height) do
      VipsHelpers.register_fonts
      Vips::Image.text(ORACLE_TEXT_METRIC_SAMPLE, font: @font).height
    end
  end

  # Bottom of the ink of capital letters within a line, i.e. the baseline.
  # The prefix's "|" pins the layer's vertical extent, as in every word layer.
  def baseline
    memo(:baseline) do
      mask = Vips::Image.text("#{ORACLE_TEXT_BASELINE_PREFIX}HXE", font: @font).extract_band(0)
      caps = mask.crop(prefix_width, 0, mask.width - prefix_width, mask.height)
      _left, top, _width, height = caps.find_trim(background: 0)
      top + height + (line_height - mask.height)
    end
  end

  private

  def bars_width
    memo(:bars_width) { text_width("||") }
  end

  def memo(name)
    @cache.fetch(name) { @cache[name] = yield }
  end
end
