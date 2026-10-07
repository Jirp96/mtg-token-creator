# frozen_string_literal: true

module Layout
  # --- Card template ---------------------------------------------------------
  # Only used for its size and rounded black outer edge; the frame is drawn on top.
  CARD_TEMPLATE_FILE_NAME = "card_template.png"
  CARD_WIDTH  = 2550
  CARD_HEIGHT = 3480

  # --- Fonts -----------------------------------------------------------------
  # Fonts live in fonts/ (see README). Missing files fall back to system fonts.
  FONT_FILES = {
    beleren: "fonts/Beleren2016-Bold-Asterisk.ttf",
    plantin: "fonts/PlantinMTProRg.TTF",
    plantin_italic: "fonts/PlantinMTProRgIt.TTF",
    mana: "fonts/NDPMTG.ttf"
  }.freeze

  TITLE_FONT_FAMILY  = "Beleren2016, Serif Bold"
  ORACLE_FONT_FAMILY = "Plantin MT Pro, Serif"
  MANA_FONT          = "NDPMTG 200"

  # --- Frame geometry (card pixels) -----------------------------------------
  # Proportions follow a modern (M15) MTG frame.
  FRAME_INSET        = 95
  FRAME_BOTTOM       = 3290
  BAR_X              = 140
  BAR_WIDTH          = CARD_WIDTH - (BAR_X * 2)
  BAR_HEIGHT         = 200
  BAR_RADIUS         = 38
  TITLE_BAR_Y        = 160
  TYPE_BAR_Y         = 1965
  BAR_TEXT_PADDING   = 55

  CARD_ART_X         = 190
  CARD_ART_Y         = 375
  CARD_ART_WIDTH     = CARD_WIDTH - (CARD_ART_X * 2)
  CARD_ART_HEIGHT    = 1575

  TEXT_BOX_X         = CARD_ART_X
  TEXT_BOX_Y         = 2180
  TEXT_BOX_WIDTH     = CARD_ART_WIDTH
  TEXT_BOX_HEIGHT    = 1060
  TEXT_BOX_PADDING_X = 75
  TEXT_BOX_PADDING_Y = 60

  PT_BOX_WIDTH       = 470
  PT_BOX_HEIGHT      = 210
  PT_BOX_X           = CARD_WIDTH - BAR_X - PT_BOX_WIDTH + 10
  PT_BOX_Y           = 3130
  # Gap kept between rules-text ink (or the second-face box) and the P/T box.
  PT_BOX_CLEARANCE   = 25

  # --- Text sizes ------------------------------------------------------------
  TITLE_FONT_SIZE     = 112
  TYPE_FONT_SIZE      = 96
  PT_FONT_SIZE        = 118
  TITLE_PIP_DIAMETER  = 118
  TITLE_PIP_GAP       = 8

  # --- Oracle text (inline mana-symbol pipeline) -----------------------------
  # Tried largest first; the first size that fits the text box wins.
  ORACLE_FONT_SIZES                = 132.step(62, -4).to_a.freeze
  ORACLE_LINE_GAP_RATIO            = 0.12
  ORACLE_PARAGRAPH_GAP_RATIO       = 0.45
  ORACLE_SYMBOL_SCALE              = 0.82
  ORACLE_TEXT_BASELINE_PREFIX      = "|Ag "
  ORACLE_TEXT_METRIC_SAMPLE        = ORACLE_TEXT_BASELINE_PREFIX
  ORACLE_SYMBOL_HORIZONTAL_PADDING = 6

  # --- Second-face box (for "prepared" double-faced tokens) ------------------
  SECOND_FACE_BOX_WIDTH    = 860
  SECOND_FACE_BOX_GAP      = 40
  SECOND_FACE_BOX_PADDING  = 28
  SECOND_FACE_BORDER       = 6
  SECOND_FACE_SEPARATOR_H  = 4
  SECOND_FACE_NAME_SIZE    = 64
  SECOND_FACE_TYPE_SIZE    = 54
  SECOND_FACE_ORACLE_SIZES = [64, 58, 52, 46].freeze
  SECOND_FACE_PIP_DIAMETER = 60

  # --- Card art --------------------------------------------------------------
  # Scryfall art_crop images use a 626x457 aspect ratio.
  ART_CROP_WIDTH_RATIO  = 626
  ART_CROP_HEIGHT_RATIO = 457

  # --- Colors (RGB, 0-255) ---------------------------------------------------
  TEXT_BLACK = [0, 0, 0].freeze
  # Matches the outer border of card_template.png.
  BORDER_BLACK = [20, 17, 15].freeze

  # Mana pip fill colors, as printed on real cards.
  MANA_COLORS = {
    "W" => [248, 231, 185],
    "U" => [179, 206, 234],
    "B" => [166, 159, 157],
    "R" => [235, 159, 130],
    "G" => [196, 211, 202]
  }.freeze
  MANA_GENERIC_COLOR = [204, 194, 193].freeze

  # Frame palettes keyed by color identity: "M" is multicolor, "C" colorless.
  #   frame: main frame color, bar: title/type/PT bar fill,
  #   box: rules-text box fill, edge: dark outline color.
  FRAME_PALETTES = {
    "W" => { frame: [222, 216, 196], bar: [236, 230, 212], box: [245, 242, 233], edge: [110, 100, 80] },
    "U" => { frame: [24, 104, 166],  bar: [168, 200, 222], box: [214, 228, 238], edge: [10, 45, 80] },
    "B" => { frame: [40, 36, 34],    bar: [168, 160, 156], box: [214, 208, 204], edge: [20, 18, 16] },
    "R" => { frame: [200, 78, 50],   bar: [232, 178, 150], box: [240, 222, 208], edge: [90, 30, 15] },
    "G" => { frame: [36, 108, 66],   bar: [176, 200, 172], box: [218, 228, 214], edge: [15, 50, 28] },
    "M" => { frame: [201, 176, 98],  bar: [212, 192, 136], box: [240, 234, 218], edge: [92, 74, 30] },
    "C" => { frame: [150, 156, 162], bar: [200, 204, 208], box: [226, 228, 230], edge: [60, 64, 70] }
  }.freeze
end
