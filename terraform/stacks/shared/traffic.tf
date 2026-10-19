locals {
  traffic_sites = ["homepage", "blog", "uses", "computer"]
  # Stable names avoid reading site state or adding a shared -> site dependency.
  # These groups are created by the site applies immediately after shared.
  traffic_sources = join(" | ", [for site in local.traffic_sites : "SOURCE 'mads-sites-${site}-access'"])
  traffic_query   = "${local.traffic_sources}\n| parse @log /mads-sites-(?<site>[^:]+)-access$/"
  html_requests   = "filter `cs-method` = 'GET' and `sc-status` >= 200 and `sc-status` < 300 and `sc-content-type` like /(?i)text\\/html/"
  traffic_panels = [
    {
      title = "Requests per hour by site (includes bots and assets)"
      view  = "timeSeries"
      query = "stats count(*) as requests by bin(1h), site"
    },
    {
      title = "Request totals by site"
      view  = "bar"
      query = "stats count(*) as requests by site | sort requests desc"
    },
    {
      title = "Successful HTML GET requests by site"
      view  = "timeSeries"
      query = "${local.html_requests} | stats count(*) as html_requests by bin(1h), site"
    },
    {
      title = "HTML requests excluding obvious bots (heuristic, not visitors)"
      view  = "bar"
      query = "${local.html_requests} | filter ispresent(`cs(User-Agent)`) and `cs(User-Agent)` != '-' and `cs(User-Agent)` not like /(?i)(bot|crawler|spider|slurp|curl|wget|python|headless|lighthouse|facebookexternalhit)/ | stats count(*) as html_requests by site | sort html_requests desc"
    },
    {
      title = "Top 30 user agents by site (all requests)"
      view  = "table"
      query = "stats count(*) as requests by site, `cs(User-Agent)` as user_agent | sort requests desc | limit 30"
    },
    {
      title = "Top 30 pages by site (successful HTML GETs)"
      view  = "table"
      query = "${local.html_requests} | stats count(*) as requests by site, `cs-uri-stem` as path | sort requests desc | limit 30"
    },
    {
      title = "Top 30 error paths (HTTP 4xx / 5xx)"
      view  = "table"
      query = "filter `sc-status` >= 400 | stats count(*) as requests by site, `cs-uri-stem` as path, `sc-status` as status | sort requests desc | limit 30"
    },
    {
      title = "Requested hostnames (including www and CloudFront hostnames)"
      view  = "table"
      query = "stats count(*) as requests by site, `x-host-header` as hostname | sort requests desc | limit 30"
    },
  ]
}

resource "aws_cloudwatch_dashboard" "traffic" {
  dashboard_name = "mads-sites-traffic"
  dashboard_body = jsonencode({
    start = "-P7D"
    widgets = concat([
      {
        type = "text", x = 0, y = 0, width = 24, height = 3
        properties = {
          markdown = "# Site traffic\nCloudFront requests for homepage, blog, uses and computer. **Requests are not unique visitors**: bots, assets and repeat requests count. HTML charts count successful HTML GETs; bot exclusion is only a user-agent heuristic. Logs start after deployment, can arrive late, and are retained for **30 days**. Blank panels do not prove there were no visits. Each refresh runs billable Logs Insights queries; use a short time range and avoid frequent auto-refresh."
        }
      }
      ], [for index, panel in local.traffic_panels : {
        type   = "log"
        x      = (index % 2) * 12
        y      = 3 + floor(index / 2) * 6
        width  = 12
        height = 6
        properties = {
          region = "us-east-1"
          title  = panel.title
          view   = panel.view
          query  = "${local.traffic_query}\n| ${panel.query}"
        }
    }])
  })
}

output "traffic_dashboard_url" {
  value = "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards/dashboard/${aws_cloudwatch_dashboard.traffic.dashboard_name}"
}
