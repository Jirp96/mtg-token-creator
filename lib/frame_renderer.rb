require "vips"

require_relative "vips_helpers"

# Draws the card chrome (colored frame, title/type bars, art window, rules-text
# box and P/T box) as an SVG, then adds a subtle grain so it reads as print
# rather than flat vector fills.
class FrameRenderer
  include VipsHelpers

  GRAIN_STRENGTH  = 0.07
  GRAIN_SCALE     = 4
  OUTLINE_WIDTH   = 7
  HIGHLIGHT_WIDTH = 5

  # `palette` is one of Layout::FRAME_PALETTES.
  def render(palette)
    chrome = Vips::Image.svgload_buffer(svg(palette))
    add_grain(chrome)
  end

  private

  def svg(palette)
    frame = palette[:frame]
    edge  = svg_color(palette[:edge])

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{CARD_WIDTH}" height="#{CARD_HEIGHT}">
        #{defs(palette)}

        <rect x="40" y="40" width="#{CARD_WIDTH - 80}" height="#{CARD_HEIGHT - 80}" rx="70" fill="#{svg_color(BORDER_BLACK)}"/>
        <rect x="#{FRAME_INSET}" y="#{FRAME_INSET}" width="#{CARD_WIDTH - (FRAME_INSET * 2)}"
              height="#{FRAME_BOTTOM - FRAME_INSET}" rx="18" fill="url(#frame)"/>
        <rect x="#{FRAME_INSET + 4}" y="#{FRAME_INSET + 4}" width="#{CARD_WIDTH - (FRAME_INSET * 2) - 8}"
              height="#{FRAME_BOTTOM - FRAME_INSET - 8}" rx="16" fill="none"
              stroke="#{svg_color(shade(frame, 1.35))}" stroke-opacity="0.7" stroke-width="6"/>

        #{window(CARD_ART_X, CARD_ART_Y, CARD_ART_WIDTH, CARD_ART_HEIGHT, "#111", edge, palette)}
        #{window(TEXT_BOX_X, TEXT_BOX_Y, TEXT_BOX_WIDTH, TEXT_BOX_HEIGHT, "url(#box)", edge, palette)}

        #{bar(BAR_X, TITLE_BAR_Y, BAR_WIDTH, BAR_HEIGHT, edge, palette)}
        #{bar(BAR_X, TYPE_BAR_Y, BAR_WIDTH, BAR_HEIGHT, edge, palette)}
        #{bar(PT_BOX_X, PT_BOX_Y, PT_BOX_WIDTH, PT_BOX_HEIGHT, edge, palette)}
      </svg>
    SVG
  end

  def defs(palette)
    <<~SVG
      <defs>
        #{metallic_gradient("frame", palette[:frame])}
        #{bar_gradient("bar", palette[:bar])}
        <linearGradient id="box" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#{svg_color(shade(palette[:box], 1.15))}"/>
          <stop offset="1" stop-color="#{svg_color(shade(palette[:box], 0.97))}"/>
        </linearGradient>
        <filter id="shadow" x="-5%" y="-20%" width="110%" height="150%">
          <feGaussianBlur in="SourceAlpha" stdDeviation="9"/>
          <feOffset dx="0" dy="10" result="blur"/>
          <feComponentTransfer><feFuncA type="linear" slope="0.6"/></feComponentTransfer>
          <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
    SVG
  end

  # A diagonal light/dark sweep that reads as a metallic frame.
  def metallic_gradient(gradient_id, rgb)
    stops = [[0, 1.15], [0.22, 0.9], [0.45, 1.07], [0.7, 0.84], [1, 1.05]].map do |offset, factor|
      %(<stop offset="#{offset}" stop-color="#{svg_color(shade(rgb, factor))}"/>)
    end
    %(<linearGradient id="#{gradient_id}" x1="0" y1="0" x2="1" y2="1">#{stops.join}</linearGradient>)
  end

  def bar_gradient(gradient_id, rgb)
    stops = [[0, 1.3], [0.45, 1.0], [1, 0.82]].map do |offset, factor|
      %(<stop offset="#{offset}" stop-color="#{svg_color(shade(rgb, factor))}"/>)
    end
    %(<linearGradient id="#{gradient_id}" x1="0" y1="0" x2="0" y2="1">#{stops.join}</linearGradient>)
  end

  # A rounded "plate" with drop shadow, dark outline and an inner highlight.
  def bar(x, y, width, height, edge, palette)
    inset = OUTLINE_WIDTH + (HIGHLIGHT_WIDTH / 2.0)
    <<~SVG
      <g filter="url(#shadow)">
        <rect x="#{x}" y="#{y}" width="#{width}" height="#{height}" rx="#{BAR_RADIUS}"
              fill="url(#bar)" stroke="#{edge}" stroke-width="#{OUTLINE_WIDTH * 2}"/>
      </g>
      <rect x="#{x + inset}" y="#{y + inset}" width="#{width - (inset * 2)}" height="#{height - (inset * 2)}"
            rx="#{BAR_RADIUS - inset}" fill="none" stroke="#{svg_color(shade(palette[:bar], 1.5))}"
            stroke-opacity="0.8" stroke-width="#{HIGHLIGHT_WIDTH}"/>
    SVG
  end

  # A recessed panel: a light bevel outside and a dark rim inside.
  def window(x, y, width, height, fill, edge, palette)
    <<~SVG
      <rect x="#{x - 8}" y="#{y - 8}" width="#{width + 16}" height="#{height + 16}"
            fill="#{svg_color(shade(palette[:frame], 1.4))}" fill-opacity="0.8"/>
      <rect x="#{x - 4}" y="#{y - 4}" width="#{width + 8}" height="#{height + 8}" fill="#{edge}"/>
      <rect x="#{x}" y="#{y}" width="#{width}" height="#{height}" fill="#{fill}"/>
    SVG
  end

  # Multiply the chrome by low-frequency noise for a printed, slightly mottled look.
  def add_grain(chrome)
    small = Vips::Image.gaussnoise(CARD_WIDTH / GRAIN_SCALE, CARD_HEIGHT / GRAIN_SCALE, sigma: 1.0, mean: 0.0, seed: 7)
    noise = small.gaussblur(1.2).resize(GRAIN_SCALE, kernel: :linear)
    noise = noise.embed(0, 0, CARD_WIDTH, CARD_HEIGHT, extend: :copy)
    factor = (noise * GRAIN_STRENGTH) + 1.0

    rgb = (chrome.extract_band(0, n: 3) * factor).cast(:uchar)
    rgb.bandjoin(chrome.extract_band(3)).copy(interpretation: :srgb)
  end
end
