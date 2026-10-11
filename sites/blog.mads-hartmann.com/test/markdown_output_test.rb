require "jekyll"
require "jekyll-md"
require "tmpdir"
require "fileutils"
require "yaml"
require_relative "../src/_plugins/llms"

def assert(condition, message)
  raise message unless condition
end

# Verify our configuration and layout against the released gem through normal
# Jekyll builds/rebuilds; converter unit tests belong to jekyll-md upstream.
blog_source = File.expand_path("../src", __dir__)
md_config = YAML.safe_load_file(File.join(blog_source, "_config.yml")).fetch("md")
Dir.mktmpdir("jekyll-md-") do |root|
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
  FileUtils.mkdir_p(source)
  File.write(File.join(root, "llms.txt"), guide)
  write.call("_layouts/markdown.liquid", File.read(File.join(blog_source, "_layouts/markdown.liquid")))
  write.call("_layouts/default.html", <<~HTML)
    <!doctype html><html><head><title>{{ page.title }}</title></head>
    <body><nav>Not article content</nav><div class="site"><a class="back-to-blog" href="/">Not article navigation</a>{{ content }}</div></body></html>
  HTML
  write.call("index.html", <<~HTML)
    ---
    title: Archive
    ---
    <h1>Archive</h1>
    <h2>Posts</h2>
    {% for post in site.posts %}<a href="{{ post.url }}">{{ post.title }}</a>{% endfor %}
  HTML
  write.call("_posts/2020-01-01-example.md", <<~'MARKDOWN')
    ---
    title: Example
    permalink: /articles/example/
    ---
    # Example & code

    {{ site.description }}

    ```sh
    echo '<tag> & value'
      indented
    ```

    | Name | Value |
    | --- | --- |
    | One | Two |

    ![Useful diagram](/images/example.png)
    [Recording](https://example.com/recording.mp3)
    <script>Not article code</script>
    <div id="disqus_thread">Not article comments</div>
  MARKDOWN
  write.call("_book_reviews/book.md", "---\ntitle: Book\n---\n# Book\n\nReview content.")
  write.call("_drafts/draft.md", "---\ntitle: Draft\npermalink: /draft.html\n---\nDraft content.")
  write.call("_posts/2999-01-01-future.md", "---\ntitle: Future\npermalink: /future.html\n---\nFuture content.")
  write.call("_posts/2020-01-02-private.md", "---\ntitle: Private\npublished: false\npermalink: /private.html\n---\nPrivate content.")
  write.call("feed.xml", "---\nlayout: null\n---\n<feed />")
  config = Jekyll.configuration(
    "source" => source, "destination" => destination, "quiet" => true,
    "url" => "https://example.com", "baseurl" => "",
    "description" => "Liquid was expanded.", "markdown" => "kramdown",
    "collections" => { "book_reviews" => { "output" => true } },
    "defaults" => [{ "scope" => { "path" => "" }, "values" => { "layout" => "default" } }],
    "md" => md_config
  )
  site = Jekyll::Site.new(config)
  site.process
  assert(read.call("llms.txt") == guide, "Publish the tracked guide unchanged")
  assert(!File.symlink?(File.join(destination, "llms.txt")), "Publish a regular guide file in development too")
  assert(read.call("index.md").include?("# Archive") && read.call("index.md").include?("[Example](/articles/example/)"), "Render the Markdown layout and Liquid archive")
  assert(read.call("index.md").scan(/^# /).length == 1, "Preserve a single archive heading")
  assert(read.call("articles/example/index.html").include?('href="/articles/example.md" type="text/markdown" rel="alternate"'), "Discover the gem's directory-page URL")
  assert(read.call("book_reviews/book.md").include?("Review content."), "Render output collections")
  markdown = read.call("articles/example.md")
  ["# Example & code", "Liquid was expanded.", "echo '<tag> & value'\n  indented", "| Name | Value |", "| One | Two |",
   "![Useful diagram](/images/example.png)", "[Recording](https://example.com/recording.mp3)",
   "Canonical page: https://example.com/articles/example/"].each do |expected|
    assert(markdown.include?(expected), "Missing #{expected.inspect} in:\n#{markdown}")
  end
  assert(!markdown.include?("Not article"), "Exclude navigation, scripts, and comments")
  %w[draft.md future.md private.md feed.md].each { |path| assert(!exists.call(path), "Do not publish #{path}") }

  # The same site instance is reused by Jekyll serve on rebuild.
  write.call("_book_reviews/book.md", "---\ntitle: Book\n---\n# Book\n\nUpdated review.")
  File.delete(File.join(source, "_posts/2020-01-01-example.md"))
  site.process
  assert(read.call("book_reviews/book.md").include?("Updated review."), "Refresh Markdown on rebuild")
  assert(!exists.call("articles/example.md") && !exists.call("articles/example/index.html"), "Remove both representations of a deleted post")
  assert(exists.call("index.md") && read.call("llms.txt") == guide, "Retain live pages and the guide on rebuild")
  Jekyll::Site.new(config.merge("show_drafts" => true)).process
  assert(exists.call("draft.md"), "Generate Markdown for the draft preview")
end
puts "jekyll-md integration verified: configuration, layout, guides, pages, posts, collections, drafts, and rebuilds."
