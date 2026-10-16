# Extend jekyll-md's HTML conversion without rewriting code samples or changing
# the HTML seen by readers. Requiring it here also fixes hook registration order.
require "jekyll-md"
require "uri"

module AgentMarkdown
  class << self
    attr_accessor :pages
  end
  self.pages = {}

  def convert(html, selector: nil)
    doc = Nokogiri::HTML(html)
    canonical = doc.at_css('link[rel="canonical"]')&.[]("href")
    return super unless canonical

    # Make the boundary explicit when converting archive links and date spans.
    doc.css(".posts .date").each { |date| date.content = " — #{date.text.strip}" }

    notes = doc.css('.footnotes li[id^="fn:"]')
    notes.each_with_index do |note, index|
      doc.css("a.footnote").select { |link| link["href"] == "##{note['id']}" }.each do |link|
        link.replace(Nokogiri::XML::Text.new("[^#{index + 1}]", doc))
      end
      note.css("a.reversefootnote").remove
    end

    doc.css("a[href], img[src]").each do |node|
      next if node.ancestors.any? { |ancestor| %w[code pre].include?(ancestor.name) }

      attribute = node.name == "a" ? "href" : "src"
      begin
        target = URI.join(canonical, node[attribute])
        # Fragment links keep their canonical HTML targets: custom heading IDs
        # aren't portable between Markdown renderers. Footnotes use native syntax.
        node[attribute] = if node.name == "a" && !target.fragment && !target.query
          AgentMarkdown.pages.fetch(target.to_s, target.to_s)
        else
          target.to_s
        end
      rescue URI::InvalidURIError
        # Preserve unusual existing URLs rather than corrupting their content.
      end
    end

    definitions = notes.each_with_index.map do |note, index|
      body = super("<main>#{note.inner_html}</main>", selector: "main").to_s.strip
      "[^#{index + 1}]: #{body.gsub("\n", "\n    ")}"
    end
    doc.css(".footnotes").remove
    markdown = super(doc.to_html, selector: selector)
    return markdown if markdown.nil? || definitions.empty?

    "#{markdown.rstrip}\n\n#{definitions.join("\n\n")}\n"
  end
end

Jekyll::Md::Converter.prepend(AgentMarkdown)

Jekyll::Hooks.register :site, :post_render do |site|
  config = Jekyll::Md::Configuration.new(site.config["md"])
  AgentMarkdown.pages = {}
  (site.pages + site.docs_to_write).each do |item|
    next unless item.destination(site.dest).end_with?(".html") && config.enabled_for?(item)

    origin = "#{site.config['url']}#{site.baseurl}"
    target = origin + Jekyll::Md::Converter.md_url_for(item.url)
    AgentMarkdown.pages[origin + item.url] = target
    if item.url.end_with?("/")
      AgentMarkdown.pages[origin + item.url + "index.html"] = target
    end
  end
end
