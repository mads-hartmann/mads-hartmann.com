"use strict";

/*
 * Turn 403 responses into 404
 */
exports.handler = async (event) => {
  // Example of origin-response payload here
  // https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-event-structure.html#lambda-event-structure-response-origin

  const response = event.Records[0].cf.response;

  if (response.status === "403") {
    console.log("Setting response to 404");
    response.status = "404";
  } else {
    console.log(`Ignoring status code ${response.status}`);
  }

  return response;
};
