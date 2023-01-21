"use strict";

/*
 * Rewrite requests to subdirectories to /index.html
 *
 * E.g both of the following
 *
 *    example.mads-hartmann.com/subdirectory
 *    example.mads-hartmann.com/subdirectory/
 *
 * Should request the following object instead
 *
 *    example.mads-hartmann.com/subdirectory/index.html
 *
 */
exports.handler = (event, context, callback) => {
  // Example origin request payload
  // https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-event-structure.html#example-origin-request
  const request = event.Records[0].cf.request;

  // The root request doesn't need re-writing, that's already handled
  // by the default_root_object property of the CloudFront distribution.
  if (request.uri == "/") {
    callback(null, request);
    return;
  }

  const endsWithSlash = request.uri.endsWith("/");
  const noExtension =
    request.uri.lastIndexOf(".") < request.uri.lastIndexOf("/");

  // If it ends with slash, just append index.html
  if (endsWithSlash) {
    request.uri = request.uri.concat("index.html");
  }
  // If it doesn't end with slash, but doesn't have an extension
  // then it's probably a subdirectory, so append /index.html
  else if (noExtension) {
    request.uri = request.uri.concat("/index.html");
  }

  callback(null, request);
};
