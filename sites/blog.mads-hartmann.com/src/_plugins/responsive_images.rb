require "json"
require "open3"

# Register generated variants as static files so both production and `jekyll serve`
# copy them normally. Originals remain available at their published URLs.
class ResponsiveImages < Jekyll::Generator
  safe true

  def generate(site)
    root = File.expand_path("../../..", site.source)
    generated = File.join(root, ".build/blog-images")
    script = File.join(File.dirname(site.source), "build-images.mjs")
    references = (site.documents + site.pages).flat_map do |page|
      page.content.scan(/\{%\s*include image\.html src="([^"]+)"/).flatten
    end
    output, error, status = Open3.capture3("node", script, site.source, generated, JSON.generate(references))
    unless status.success?
      raise Jekyll::Errors::FatalException, "Image build failed: #{error}"
    end
    site.data["responsive_images"] = JSON.parse(output)
    site.data["responsive_images"].each_value do |image|
      image["variants"].each do |variant|
        site.static_files << Jekyll::StaticFile.new(site, generated, "", variant["url"].delete_prefix("/"))
      end
    end
  end
end
