// CloudFront Functions runtime 2.0. Keep below the 10 KB source limit.
var redirects = __REDIRECTS__;
function redirect(url) {
  return { statusCode: 301, statusDescription: 'Moved Permanently', headers: { location: { value: url } } };
}
function handler(event) {
  var request = event.request;
  var path = request.uri.replace(/\/$/, '') || '/';
  if (redirects[path]) return redirect(redirects[path]);
  if (path === '/blog' || path === '/writings') return redirect('https://blog.mads-hartmann.com/');
  if (path.indexOf('/blog/images/') === 0 || path.indexOf('/blog/uploads/') === 0 || path === '/blog/feed.xml') return redirect('https://blog.mads-hartmann.com' + path.slice(5));
  if (path === '/uses') return redirect('https://uses.mads-hartmann.com/');
  if (path === '/tools' || path.indexOf('/tools/') === 0 || path === '/photography') return { statusCode: 410, statusDescription: 'Gone', body: 'Gone.' };
  if (path !== '/' && path !== '/index.html') return { statusCode: 404, statusDescription: 'Not Found', body: 'Page not found.' };
  if (request.headers.host.value === 'mads-hartmann.com') return redirect('https://www.mads-hartmann.com/');
  request.uri = '/index.html';
  return request;
}
