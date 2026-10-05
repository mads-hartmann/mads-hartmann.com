// CloudFront Functions runtime 2.0. Keep below the 10 KB source limit.
var redirects = __REDIRECTS__;
function redirect(url, query) {
  var parts = [];
  // CloudFront supplies URL-encoded keys and values; preserve that encoding.
  for (var key in query) {
    var values = query[key].multiValue || [query[key]];
    for (var i = 0; i < values.length; i++) parts.push(key + '=' + values[i].value);
  }
  return { statusCode: 301, statusDescription: 'Moved Permanently', headers: { location: { value: url + (parts.length ? '?' + parts.join('&') : '') } } };
}
function handler(event) {
  var request = event.request;
  var path = request.uri.replace(/\/$/, '') || '/';
  var query = request.querystring || {};
  if (redirects[path]) return redirect(redirects[path], query);
  if (path === '/blog' || path === '/writings') return redirect('https://blog.mads-hartmann.com/', query);
  if (path.indexOf('/blog/images/') === 0 || path.indexOf('/blog/uploads/') === 0 || path === '/blog/feed.xml') return redirect('https://blog.mads-hartmann.com' + path.slice(5), query);
  if (path === '/uses') return redirect('https://uses.mads-hartmann.com/', query);
  if (path === '/tools' || path.indexOf('/tools/') === 0 || path === '/photography') return { statusCode: 410, statusDescription: 'Gone', body: 'Gone.' };
  if (path !== '/' && path !== '/index.html') return { statusCode: 404, statusDescription: 'Not Found', body: 'Page not found.' };
  if (request.headers.host.value === 'mads-hartmann.com') return redirect('https://www.mads-hartmann.com/', query);
  request.uri = '/index.html';
  return request;
}
