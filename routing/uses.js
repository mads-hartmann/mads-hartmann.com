function handler(event) {
  var request = event.request;
  if (/^\/_assets\/[a-f0-9]{64}\/.+/.test(request.uri)) return request;
  if (['/', '/index.html', '/index.md', '/llms.txt', '/robots.txt', '/sitemap.xml'].indexOf(request.uri) === -1) return { statusCode: 404, statusDescription: 'Not Found', body: 'Page not found.' };
  if (request.uri === '/') request.uri = '/index.html';
  return negotiateMarkdown(request);
}
