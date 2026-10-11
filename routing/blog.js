var redirects = __REDIRECTS__;
function handler(event) {
  var request = event.request;
  var target = redirects[request.uri.replace(/%2c/gi, ',')];
  if (target) {
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: { location: { value: target } }
    };
  }
  // The source uses both directory indexes and dated .html permalinks.
  if (request.uri.endsWith('/')) request.uri += 'index.html';
  else if (!request.uri.split('/').pop().includes('.')) request.uri += '/index.html';
  // jekyll-md publishes directory pages at /directory.md, with /index.md
  // reserved for the homepage. Explicit and negotiated URLs must agree.
  if (request.uri !== '/index.html' && request.uri.endsWith('/index.html') && prefersMarkdown(request.headers)) {
    request.uri = request.uri.slice(0, -11) + '.md';
    return request;
  }
  return negotiateMarkdown(request);
}
