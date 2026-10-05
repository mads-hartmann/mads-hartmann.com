require "json"
require "open3"

module SharedHeader
  class Generator < Jekyll::Generator
    safe true

    def generate(site)
      renderer = File.expand_path("../../../shared/header/render.mjs", __dir__)
      output, error, status = Open3.capture3("node", renderer)
      unless status.success?
        raise Jekyll::Errors::FatalException, "Shared header build failed: #{error}"
      end
      site.data["shared_headers"] = JSON.parse(output)
    end
  end
end
