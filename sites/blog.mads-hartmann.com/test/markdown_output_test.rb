require "jekyll"
require "tmpdir"
require "fileutils"
require_relative "../src/_plugins/markdown_output"

def assert(condition, message)
  raise message unless condition
end

# Exercise Jekyll's normal render/write/clean lifecycle, without a post-build tool.
Dir.mktmpdir("jekyll-markdown-") do |root|
  source = File.join(root, "src")
  destination = File.join(root, "output")
  write = lambda do |path, content|
    target = File.join(source, path)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, content)
  end
  read = ->(path) { File.read(File.join(destination, path)) }
  exists = ->(path) { File.exist?(File.join(destination, path)) }
  guide = "# Fixture\n\nA manually maintained guide.\n"
  File.write(File.join(root, "llms.txt"), guide)
  write.call("_layouts/default.html", <<~HTML)
    <!doctype html><html><head><title>{{ page.title }}</title>
    <link rel="alternate" type="text/markdown" href="{{ page.markdown_url }}">
    </head><body><nav>Not article content</nav><main>{{ content }}</main></body></html>
  HTML
  write.call("index.html", <<~HTML)
    ---
    title: Archive
    ---
    <h1>Archive</h1>{% for post in site.posts %}<a href="{{ post.url | relative_url }}">{{ post.title }}</a>{% endfor %}
  HTML
  write.call("_posts/2020-01-01-example.md", <<~'MARKDOWN')
    ---
    title: Example
    permalink: /articles/example/
    ---
    # Example & code

    {{ site.description }}

    [Archive]({{ '/' | relative_url }}) [Footnote](#note)

    ````sh
    echo '<tag> & value'
      indented
    ```
    ````

    | Name | Value |
    | --- | --- |
    | One | Two |

    <details><summary>More detail</summary><p>Still readable</p></details>
    <img src="/images/example.png" alt="Useful diagram"><img src="data:image/png;base64,abc" alt="Portrait">
    <audio controls><source src="/recording.mp3"></audio><iframe src="https://example.net/video" title="Conference talk"></iframe>
    <a href="/café.html">Unicode URL</a>
    <script>Not article code</script>
  MARKDOWN
  write.call("_book_reviews/book.md", "---\ntitle: Book\n---\n# Book\n\nReview content.")
  write.call("_drafts/draft.md", "---\ntitle: Draft\npermalink: /draft.html\n---\nDraft content.")
  write.call("_posts/2999-01-01-future.md", "---\ntitle: Future\npermalink: /future.html\n---\nFuture content.")
  write.call("_posts/2020-01-02-private.md", "---\ntitle: Private\npublished: false\npermalink: /private.html\n---\nPrivate content.")
  write.call("feed.xml", "---\nlayout: null\n---\n<feed />")
  config = Jekyll.configuration(
    "source" => source, "destination" => destination, "quiet" => true,
    "url" => "https://example.com", "baseurl" => "/preview",
    "description" => "Liquid was expanded.", "markdown" => "kramdown",
    "collections" => { "book_reviews" => { "output" => true } },
    "defaults" => [{ "scope" => { "path" => "" }, "values" => { "layout" => "default" } }],
    "markdown_output" => { "enabled" => true, "llms_txt" => "../llms.txt" }
  )
  site = Jekyll::Site.new(config)
  site.process
  assert(read.call("llms.txt") == guide, "Publish the tracked guide unchanged")
  assert(read.call("index.md").include?("https://example.com/preview/articles/example/index.md"), "Resolve Liquid archive links to Markdown")
  assert(read.call("articles/example/index.html").include?('href="https://example.com/preview/articles/example/index.md"'), "Expose the sibling Markdown URL")
  assert(read.call("book_reviews/book.md").include?("Review content."), "Render output collections")
  markdown = read.call("articles/example/index.md")
  ["# Example & code", "Liquid was expanded.", "[Archive](https://example.com/preview/index.md)",
   "[Footnote](https://example.com/preview/articles/example/#note)",
   "````sh\necho '<tag> & value'\n  indented\n```\n````", "| Name | Value |", "| One | Two |",
   "More detail", "Still readable", "![Useful diagram](https://example.com/images/example.png)", "Portrait",
   "(https://example.com/recording.mp3)", "[Conference talk](https://example.net/video)",
   "https://example.com/caf%C3%A9.html"].each do |expected|
    assert(markdown.include?(expected), "Missing #{expected.inspect} in:\n#{markdown}")
  end
  assert(!markdown.match?(/Not article|data:image/), "Exclude page chrome and embedded image bytes")
  %w[draft.md future.md private.md feed.md].each { |path| assert(!exists.call(path), "Do not publish #{path}") }

  # The same site instance is reused by Jekyll serve on rebuild.
  File.delete(File.join(source, "_posts/2020-01-01-example.md"))
  site.process
  assert(!exists.call("articles/example/index.md") && !exists.call("articles/example/index.html"), "Remove both representations of a deleted post")
  assert(exists.call("index.md") && exists.call("llms.txt"), "Retain live pages and the guide on rebuild")
  Jekyll::Site.new(config.merge("show_drafts" => true)).process
  assert(exists.call("draft.md"), "Generate Markdown for the draft preview")
  Jekyll::Site.new(config.merge("markdown_output" => { "enabled" => false })).process
  assert(!exists.call("index.md") && !exists.call("llms.txt"), "Allow configuration to disable Markdown output")
end
puts "Jekyll Markdown verified: pages, posts, collections, Liquid, permalinks, content, drafts, and cleanup."
