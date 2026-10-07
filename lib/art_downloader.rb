require "net/http"
require "uri"

# Downloads card art, retrying transient failures. Returns nil (with a
# warning) when the art cannot be fetched so the card still renders.
module ArtDownloader
  ART_DOWNLOAD_TIMEOUT = 15 # seconds
  ART_DOWNLOAD_RETRIES = 2

  def self.fetch(image_url)
    return nil if image_url.to_s.empty?

    uri = URI(image_url)
    http_options = {
      use_ssl: uri.scheme == "https",
      open_timeout: ART_DOWNLOAD_TIMEOUT,
      read_timeout: ART_DOWNLOAD_TIMEOUT
    }
    retries = 0

    begin
      Net::HTTP.start(uri.hostname, uri.port, **http_options) do |http|
        response = http.request(Net::HTTP::Get.new(uri))
        return response.body if response.is_a?(Net::HTTPSuccess)

        warn "Could not download art from #{image_url} (HTTP #{response.code}). Rendering without art."
        return nil
      end
    rescue StandardError => e
      retries += 1
      retry if retries <= ART_DOWNLOAD_RETRIES

      warn "Could not download art from #{image_url}: #{e.message}. Rendering without art."
      nil
    end
  end
end
