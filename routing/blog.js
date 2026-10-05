var redirects = __REDIRECTS__;
function handler(event) {
  var request = event.request;
  var target = redirects[request.uri.replace(/%2c/gi, ',')];
  if (target) {
    var parts = [];
    var query = request.querystring || {};
    for (var key in query) {
      var values = query[key].multiValue || [query[key]];
      for (var i = 0; i < values.length; i++) parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(values[i].value));
    }
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: { location: { value: target + (parts.length ? '?' + parts.join('&') : '') } }
    };
  }
  // The source uses both directory indexes and dated .html permalinks.
  if (request.uri.endsWith('/')) request.uri += 'index.html';
  else if (!request.uri.split('/').pop().includes('.')) request.uri += '/index.html';
  return request;
}
