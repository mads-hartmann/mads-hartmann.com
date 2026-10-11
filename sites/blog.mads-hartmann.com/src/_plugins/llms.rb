# Keep the editable guide in the project folder and publish it as a normal
# Jekyll static file. Source symlinks remain symlinks in development builds.
class LLMGuide < Jekyll::Generator
  safe true

  def generate(site)
    site.static_files << Jekyll::StaticFile.new(site, File.dirname(site.source), "", "llms.txt")
  end
end
