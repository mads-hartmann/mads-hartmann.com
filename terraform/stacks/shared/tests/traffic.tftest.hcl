mock_provider "aws" {}

run "traffic_dashboard" {
  command = plan
  # The dashboard is independent of the existing DNS record imports.
  plan_options { target = [aws_cloudwatch_dashboard.traffic] }
  assert {
    condition = alltrue([for widget in jsondecode(aws_cloudwatch_dashboard.traffic.dashboard_body).widgets :
      widget.type != "log" ? true : (
        widget.properties.region == "us-east-1" &&
        alltrue([for site in ["homepage", "blog", "uses", "computer"] : strcontains(widget.properties.query, "SOURCE 'mads-sites-${site}-access'")]) &&
        strcontains(widget.properties.query, "by") && strcontains(widget.properties.query, "site")
      )
    ])
    error_message = "Every query must include all four sites in the CloudFront log region and preserve the site breakdown."
  }
  assert {
    condition = alltrue([for widget in jsondecode(aws_cloudwatch_dashboard.traffic.dashboard_body).widgets :
      !strcontains(try(widget.properties.query, ""), "as html_requests") ? true : (
        strcontains(widget.properties.query, "`cs-method` = 'GET'") &&
        strcontains(widget.properties.query, "`sc-status` >= 200") &&
        strcontains(widget.properties.query, "`sc-status` < 300") &&
        strcontains(widget.properties.query, "`sc-content-type` like")
      )
    ])
    error_message = "HTML request charts must exclude assets, errors, redirects and HEAD requests."
  }
}
