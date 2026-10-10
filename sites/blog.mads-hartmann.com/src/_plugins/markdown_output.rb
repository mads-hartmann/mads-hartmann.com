require "fileutils"
require "pathname"
require "reverse_markdown"
require "addressable/uri"

# Jekyll owns both representations. Register sidecars as site files so its writer
# and cleaner handle them, including removing Markdown for deleted posts.
module MarkdownOutput
  class Sidecar < Jekyll::StaticFile
    attr_accessor :content

    def modified_time
      @site.time
    end

    def write(destination)
      target = self.destination(destination)
      # Jekyll can skip rendering unchanged pages during incremental builds.
      return false if content.nil? && File.file?(target)
      raise Jekyll::Errors::FatalException, "Markdown was not rendered: #{relative_path}" if content.nil?

      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, content)
      true
    end
  end

  # Rouge nests spans inside <code> and puts the language on a wrapper. Preserve
  # code text, indentation, and embedded backticks without converting the spans.
  class CodeBlock < ReverseMarkdown::Converters::Base
    def convert(node, _state = {})
      code = node.at_css("code") || node
      language = ([code] + code.ancestors.to_a).filter_map do |element|
        element["class"].to_s[/(?:language-|lang-)([\w+-]+)/, 1]
      end.first.to_s
      text = code.text.sub(/\n\z/, "")
      fence = "`" * ([2] + text.scan(/`+/).map(&:length)).max.succ
      "\n\n#{fence}#{language}\n#{text}\n#{fence}\n\n"
    end
  end
  ReverseMarkdown::Converters.register :pre, CodeBlock.new

  def self.absolute_url(site, path)
    "#{site.config.fetch('url').delete_suffix('/')}#{site.baseurl}#{path}"
  end

  def self.prepare(site)
    config = site.config.fetch("markdown_output", {})
    return unless config["enabled"]

    pages = site.pages + site.documents.select(&:write?)
    pages.select! { |page| page.output_ext == ".html" }
    urls = {}
    pages.each do |page|
      path = Pathname.new(page.destination(site.dest)).relative_path_from(Pathname.new(site.dest)).to_s
      markdown_path = path.sub(/\.html\z/, ".md")
      sidecar = Sidecar.new(site, site.source, "", markdown_path)
      page.instance_variable_set(:@markdown_sidecar, sidecar)
      site.static_files << sidecar
      page.data["markdown_url"] = absolute_url(site, "/#{markdown_path}")
      canonical = absolute_url(site, page.url).sub(/index\.html\z/, "")
      urls[canonical] = urls[absolute_url(site, "/#{path}")] = page.data["markdown_url"]
      urls[canonical.delete_suffix("/")] = page.data["markdown_url"] if canonical.end_with?("/")
    end
    site.instance_variable_set(:@markdown_urls, urls)

    guide = File.expand_path(config.fetch("llms_txt"), site.source)
    raise Jekyll::Errors::FatalException, "Missing llms.txt: #{guide}" unless File.file?(guide)

    site.static_files << Jekyll::StaticFile.new(site, File.dirname(guide), "", File.basename(guide))
  end

  def self.render(page)
    sidecar = page.instance_variable_get(:@markdown_sidecar)
    return unless sidecar

    canonical = absolute_url(page.site, page.url).sub(/index\.html\z/, "")
    document = Nokogiri::HTML(page.output)
    content = document.at_css("main, .site")
    raise Jekyll::Errors::FatalException, "No main content in #{page.url}" unless content

    title = (content.at_css("h1") || document.at_css("title"))&.text.to_s.strip
    content.css("script, style, nav, footer, template, #disqus_thread").remove
    # The older post layout puts its excerpt before the title and date.
    heading = content.element_children.find { |node| node["class"].to_s.split.include?("title") }
    content.children.first.add_previous_sibling(heading) if heading && heading != content.children.first

    content.css("[href], [src]").each do |node|
      %w[href src].each do |attribute|
        value = node[attribute]
        next if value.nil? || value.empty?
        if value.start_with?("data:")
          node.replace(Nokogiri::XML::Text.new(node["alt"].to_s, document)) if node.name == "img"
          next
        end
        url = Addressable::URI.join(canonical, value).normalize
        target = page.site.instance_variable_get(:@markdown_urls)[url.to_s]
        node[attribute] = attribute == "href" && !url.fragment && target ? target : url.to_s
      end
    end
    content.css("iframe, audio, video").each do |node|
      links = Nokogiri::XML::Node.new("p", document)
      ([node] + node.css("source").to_a).filter_map { |source| source["src"] }.each do |source|
        link = Nokogiri::XML::Node.new("a", document)
        link["href"] = source
        link.content = node["title"] || "#{node.name} recording"
        links.add_child(link)
        links.add_child(Nokogiri::XML::Node.new("br", document))
      end
      node.replace(links)
    end
    markdown = ReverseMarkdown.convert(content.to_html, github_flavored: true, unknown_tags: :bypass).strip
    markdown = "# #{title}\n\n#{markdown}" unless content.at_css("h1")
    sidecar.content = "#{markdown}\n\n---\n\nCanonical page: #{canonical}\n"
  end
end

Jekyll::Hooks.register :site, :pre_render do |site|
  MarkdownOutput.prepare(site)
end
Jekyll::Hooks.register [:pages, :documents], :post_render do |page|
  MarkdownOutput.render(page)
end
