{ pkgs, ... }:
{
  languages.ruby.enable = true;
  processes = {
    serve.exec = "bundle install && bundle exec jekyll serve --watch --drafts --source src";
  };
}
