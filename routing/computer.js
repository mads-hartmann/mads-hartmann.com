function handler(event) {
  var request = event.request;
  if (/^\/_assets\/[a-f0-9]{64}\/.+/.test(request.uri)) return request;
  if (request.uri === '/') request.uri = '/index.html';
  if (/^\/v[123]\/?$/.test(request.uri)) request.uri = request.uri.replace(/\/$/, '') + '.html';
  if (['/index.html', '/index.md', '/v1.html', '/v2.html', '/v3.html', '/v1.md', '/v2.md', '/v3.md', '/llms.txt', '/robots.txt', '/sitemap.xml'].indexOf(request.uri) === -1) {
    return { statusCode: 404, statusDescription: 'Not Found', body: 'Page not found.' };
  }
  return negotiateMarkdown(request);
}
