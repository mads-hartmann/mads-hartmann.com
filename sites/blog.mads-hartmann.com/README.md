# blog.mads-hartmann.com

Requires Node 24 as well as Ruby and Bundler. The Jekyll plugin invokes the shared
header renderer once per build; the default layout selects the Blog version.
It works with both `scripts/build.sh blog` and Jekyll's development server.

The former About content lives on Home. CloudFront redirects `/about`, `/about/`
and `/about/index.html` to `https://www.mads-hartmann.com/`, preserving query parameters.

```
cd sites/blog.mads-hartmann.com
bundle install
bundle exec jekyll serve --watch --drafts --source src
```

Restart the development server after editing `sites/shared/header`: those files
are outside Jekyll's watched source directory.
