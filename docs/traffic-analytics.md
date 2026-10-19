# Site traffic in AWS

Open [mads-sites-traffic in CloudWatch](https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards/dashboard/mads-sites-traffic)
after deployment. The shared stack also outputs `traffic_dashboard_url`.
The default range is seven days; use the dashboard time picker to change it.

The dashboard shows hourly requests and totals by homepage, blog, uses and computer,
successful HTML GETs, HTML requests excluding obvious bot user agents, top user
agents, popular pages, error paths and requested hostnames (including www).
Each query keeps the site dimension. To investigate one site or user agent,
open a panel in Logs Insights and add, for example, `| filter site = 'blog'`
before its `stats` command.

## What the numbers mean

CloudFront standard logging v2 captures viewer requests, including cache hits.
S3 access logs would miss those cached visits. No client-side analytics script,
cookie or change to the sites' content security policies is needed.

Requests are not unique visitors or sessions. A page load can request multiple
assets; bots, HEAD requests and repeat requests also contribute to totals.
The HTML panels count only GET requests with a 2xx status and a `text/html`
response content type. They exclude redirects, 304 revalidations, assets and
errors. Visits served entirely from a browser cache never reach CloudFront.
The bot-exclusion panel uses a deliberately simple user-agent pattern; bots can
look like browsers, so the result must not be presented as a human visitor count.
User-agent and path values may appear URL-encoded as delivered by CloudFront.

The site label comes from the distribution's log group, so www aliases and
requests to a CloudFront hostname still belong to the correct site. The hostname
panel shows those differences separately.

Standard logs are best-effort and delayed, not a real-time or complete audit
trail. Delivery typically occurs within an hour, but individual entries can be
delayed by up to 24 hours. Logging starts when enabled; it does not backfill past
traffic. Blank widgets can mean delivery delay, a query error or no matching
requests. They are not proof of no visits.

## Retention and costs

Each site owns a Standard CloudWatch log group named `mads-sites-<site>-access`
in `us-east-1`, retained for 30 days. Only selected fields are delivered: date,
time, method, requested hostname, path, status, user agent, content type, bytes,
elapsed time and cache result. IP addresses, forwarded IPs, cookies, referrers and
query strings are omitted. Paths and user agents are still untrusted client data.
There is no persistent visitor identifier or unique-visitor estimate.

CloudWatch charges can include vended-log delivery/ingestion, storage, dashboard
usage and Logs Insights bytes scanned. Each dashboard load/refresh runs eight
queries. Prefer a short time range and avoid frequent automatic refreshes.
Thirty-day retention bounds storage duration, not ingestion or query charges;
high bot traffic can still increase costs. There are no custom metrics, Lambda
processors, Kinesis streams or QuickSight subscriptions in this implementation.
See [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) for current
regional rates and free-tier allowances.

## Deployment and verification

1. Review and manually apply the kernel change using the existing
   [kernel workflow](deployment.md#updating-the-kernel) **before** running
   authenticated component plans or merging the component changes. It installs
   the log-delivery resource policy and grants
   each component the new resource permissions. CI never receives permission to
   administer account-wide CloudWatch Logs resource policies.
2. Merge through the normal checked PR workflow. Shared creates the dashboard,
   then the four site stacks create their log groups and standard-v2 delivery
   sources, destinations and connections. During the first deployment the
   dashboard can report missing log groups until the site applies finish.
3. Visit each site, then check the four log groups in `us-east-1` after allowing
   for delivery delay. Confirm JSON records contain `cs(User-Agent)`,
   `cs-uri-stem`, `sc-status` and `sc-content-type`, with no omitted private fields.
4. Open the dashboard with a suitable time range. Confirm all eight queries run,
   each visited site appears, HTML requests populate the HTML panels, and asset
   requests contribute to totals but not HTML counts. Use a distinctive user
   agent on a test request to verify that breakdown.

The dashboard viewer needs `cloudwatch:GetDashboard`, `logs:DescribeLogGroups`,
`logs:StartQuery` on the four log groups, and `logs:GetQueryResults` /
`logs:StopQuery` to view and control results. These human viewing permissions
are separate from the CI deployment roles.

If delivery fails, check the delivery source/destination/connection in
`us-east-1` and the kernel's `mads-sites-traffic` resource policy. CloudFront
supports one delivery source per distribution; import any manually configured
source into the matching Terraform resource instead of creating a second one.
The resource policy permits only this account's named site delivery sources to
write to their matching log groups.

Terraform validation and mock tests check configuration, data-selection and IAM
boundaries. They cannot execute Logs Insights queries or establish that AWS
accepted delivery permissions; authenticated plans, applies and the checks above
are required to verify the live pipeline.

References: [CloudFront standard logging v2](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/standard-logging.html)
and [CloudWatch log-delivery permissions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AWS-logs-infrastructure-V2-CloudWatchLogs.html).
