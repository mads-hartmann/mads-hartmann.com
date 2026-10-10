function handler(event) {
  var request = event.request;
  if (request.uri !== '/' && request.uri !== '/index.html' && request.uri !== '/index.md' && request.uri !== '/llms.txt') return { statusCode: 404, statusDescription: 'Not Found', body: 'Page not found.' };
  if (request.uri === '/') request.uri = '/index.html';
  return negotiateMarkdown(request);
}
