require "spec_helper"
require "tmpdir"
require "vips"
require "pdf_generation"

RSpec.describe PdfGeneration do
  describe ".mm_to_pt" do
    it "converts millimetres to PDF points (72dpi over 25.4mm/inch)" do
      expect(described_class.mm_to_pt(25.4)).to be_within(1e-9).of(72.0)
    end

    it "converts zero to zero" do
      expect(described_class.mm_to_pt(0)).to eq(0)
    end

    it "converts an A4 width" do
      expect(described_class.mm_to_pt(210)).to be_within(1e-6).of(595.2755905511812)
    end
  end

  describe ".generate" do
    it "writes a valid PDF assembled from the jpgs in a directory" do
      Dir.mktmpdir do |dir|
        images_dir = File.join(dir, "cards")
        Dir.mkdir(images_dir)

        4.times do |i|
          card = Vips::Image.black(120, 168).new_from_image([i * 40, 80, 160])
          card.write_to_file(File.join(images_dir, format("card_%02d.jpg", i)))
        end

        Dir.chdir(dir) do
          described_class.generate(images_dir, "sheet")

          output = File.join(dir, "sheet.pdf")
          expect(File).to exist(output)
          expect(File.read(output, 8)).to start_with("%PDF")
        end
      end
    end
  end
end
