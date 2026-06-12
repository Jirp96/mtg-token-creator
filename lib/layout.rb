# frozen_string_literal: true

# Single source of truth for the magic numbers, fonts, and colors used when
# rendering a card image. Values are intentionally identical to the previous
# inline constants — this module only groups and namespaces them.
module Layout
  # --- Card template ---------------------------------------------------------
  CARD_TEMPLATE_FILE_NAME = "card_template.png"

  # --- Card text blocks (positions are in template pixels) -------------------
  CARD_TYPES_FONT           = "Sans Bold 80"
  CARD_TEXT_SIZE            = 2200
  CARD_TEXT_X_MARGIN        = 200
  CARD_TITLE_POSITION       = 120
  CARD_TYPES_POSITION       = 1900
  CARD_STAT_LINE_X_POSITION = 2000
  CARD_STAT_LINE_Y_POSITION = 3200
  CARD_ORACLE_TEXT_POSITION = 2200
  CARD_ART_X                = 200
  CARD_ART_Y                = 300
  CARD_TITLE_X              = CARD_ART_X

  # --- Mana pips -------------------------------------------------------------
  CARD_PIPS_FONT = "NDPMTG 150"

  # --- Oracle text (inline mana-symbol pipeline) -----------------------------
  ORACLE_TEXT_FONT                 = "Sans 90"
  ORACLE_SYMBOL_FONT               = "NDPMTG 105"
  ORACLE_SYMBOL_FONT_FILE          = "fonts/NDPMTG.ttf"
  ORACLE_LINE_GAP                  = 24
  ORACLE_TEXT_BASELINE_PREFIX      = "Ag "
  ORACLE_TEXT_METRIC_SAMPLE        = "#{ORACLE_TEXT_BASELINE_PREFIX}ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789,.:;()'/-".freeze
  ORACLE_SYMBOL_HORIZONTAL_PADDING = 10
  ORACLE_SYMBOL_BASELINE_ADJUST    = 0

  # --- Second-face box (for "prepared" double-faced tokens) ------------------
  SECOND_FACE_BOX_WIDTH   = 880
  SECOND_FACE_BOX_HEIGHT  = 950
  SECOND_FACE_BOX_GAP     = 40
  SECOND_FACE_BOX_PADDING = 25
  SECOND_FACE_BORDER      = 5
  SECOND_FACE_SEPARATOR_H = 4
  SECOND_FACE_NAME_FONT   = "Sans Bold 64"
  SECOND_FACE_TYPE_FONT   = "Sans Bold 56"
  SECOND_FACE_ORACLE_FONT = "Sans 70"
  SECOND_FACE_PIPS_FONT   = "NDPMTG 90"

  # --- Card art --------------------------------------------------------------
  # Scryfall art_crop images use a 626x457 aspect ratio.
  ART_CROP_WIDTH_RATIO  = 626
  ART_CROP_HEIGHT_RATIO = 457
  CARD_ART_WIDTH        = 2100
  CARD_ART_HEIGHT       = (CARD_ART_WIDTH * ART_CROP_HEIGHT_RATIO.to_f / ART_CROP_WIDTH_RATIO).round

  # --- Colors (RGBA, 0-255) --------------------------------------------------
  TEXT_BLACK               = [0, 0, 0].freeze
  SECOND_FACE_BORDER_COLOR = [30, 60, 120, 255].freeze
  SECOND_FACE_BG_COLOR     = [205, 220, 240, 255].freeze
end
