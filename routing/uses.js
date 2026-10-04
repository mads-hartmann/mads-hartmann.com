function handler(event) {
  var request = event.request;
  if (request.uri !== '/' && request.uri !== '/index.html') return { statusCode: 404, statusDescription: 'Not Found', body: 'Page not found.' };
  request.uri = '/index.html';
  return request;
}
