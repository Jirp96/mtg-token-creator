require "prawn"

PAGE_WIDTH_RAW = 210
PAGE_HEIGHT_RAW = 297
CARD_WIDTH_RAW = 69
CARD_HEIGHT_RAW = 94

module PdfGeneration
  def self.generate(cards_image_path, output_file_name)
    
    page_width = mm_to_pt(PAGE_WIDTH_RAW)
    page_height = mm_to_pt(PAGE_HEIGHT_RAW)
    card_width = mm_to_pt(CARD_WIDTH_RAW)
    card_height = mm_to_pt(CARD_HEIGHT_RAW)

    Prawn::Document.generate(
      "#{output_file_name}.pdf",
      page_size: [page_width, page_height],
      margin: 0
    ) do |pdf|
      x = 0
      y = page_height

      Dir["#{cards_image_path}/*.png"].each_with_index do |img, i|
        pdf.image img, at: [x, y], width: card_width

        x += card_width
        if x + card_width > page_width
          x = 0
          y -= card_height
        end

        if y < card_height
          pdf.start_new_page
          x = 0
          y = page_height
        end
      end
    end
  end

  def self.mm_to_pt(mm)
    mm * 72.0 / 25.4
  end
end