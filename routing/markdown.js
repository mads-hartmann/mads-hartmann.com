// Shared by all viewer-request functions. URI selection happens before the
// CloudFront cache lookup, so HTML and Markdown have separate cache keys.
function prefersMarkdown(headers) {
  var header = headers && headers.accept;
  if (!header) return false;
  var value = header.multiValue ? header.multiValue.map(function (item) { return item.value; }).join(',') : header.value;
  var ranges = value.toLowerCase().split(',');
  var markdown = -1;
  var html = -1;
  var htmlSpecificity = -1;
  for (var i = 0; i < ranges.length; i++) {
    var parts = ranges[i].trim().split(';');
    var type = parts[0].trim();
    var quality = 1;
    for (var j = 1; j < parts.length; j++) {
      var parameter = parts[j].trim();
      if (parameter.indexOf('q=') === 0) {
        var raw = parameter.slice(2).trim();
        quality = /^(0(\.\d{0,3})?|1(\.0{0,3})?)$/.test(raw) ? Number(raw) : 0;
      }
    }
    // Wildcards alone never opt a browser or crawler into Markdown.
    if (type === 'text/markdown') markdown = Math.max(markdown, quality);
    var specificity = type === 'text/html' ? 2 : type === 'text/*' ? 1 : type === '*/*' ? 0 : -1;
    if (specificity > htmlSpecificity) { html = quality; htmlSpecificity = specificity; }
    else if (specificity >= 0 && specificity === htmlSpecificity) html = Math.max(html, quality);
  }
  return markdown > 0 && markdown >= html;
}
function negotiateMarkdown(request) {
  if (request.uri.endsWith('.html') && prefersMarkdown(request.headers)) {
    request.uri = request.uri.slice(0, -5) + '.md';
  }
  return request;
}
