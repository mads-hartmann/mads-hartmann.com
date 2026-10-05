function handler(event) {
  var request = event.request;
  // Send the category-prefixed permalink to the canonical post URL.
  if (request.uri.replace(/%2c/gi, ',') === '/sre,/reliability/2021/03/14/increment-magazine.html') {
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: { location: { value: '/sre/2021/03/14/increment-magazine.html' } }
    };
  }
  // The source uses both directory indexes and dated .html permalinks.
  if (request.uri.endsWith('/')) request.uri += 'index.html';
  else if (!request.uri.split('/').pop().includes('.')) request.uri += '/index.html';
  return request;
}
