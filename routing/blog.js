function handler(event) {
  var request = event.request;
  if (request.uri === '/about' || request.uri === '/about/' || request.uri === '/about/index.html') {
    var parts = [];
    var query = request.querystring || {};
    for (var key in query) {
      var values = query[key].multiValue || [query[key]];
      for (var i = 0; i < values.length; i++) parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(values[i].value));
    }
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: { location: { value: 'https://www.mads-hartmann.com/' + (parts.length ? '?' + parts.join('&') : '') } }
    };
  }
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
