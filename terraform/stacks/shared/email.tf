# Fastmail is the only authorized sender for this domain. SPF intentionally uses
# -all instead of Fastmail's compatibility default (?all). Keep all three DKIM
# CNAMEs so Fastmail can rotate signing keys without a DNS deployment.
resource "aws_route53_record" "mail_mx" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = aws_route53_zone.primary.name
  type    = "MX"
  ttl     = 300
  records = ["10 in1-smtp.messagingengine.com.", "20 in2-smtp.messagingengine.com."]
}

resource "aws_route53_record" "mail_spf" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = aws_route53_zone.primary.name
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:spf.messagingengine.com -all"]
}

resource "aws_route53_record" "mail_dkim" {
  for_each = toset(["fm1", "fm2", "fm3"])
  zone_id  = aws_route53_zone.primary.zone_id
  name     = "${each.key}._domainkey.mads-hartmann.com"
  type     = "CNAME"
  ttl      = 300
  records  = ["${each.key}.mads-hartmann.com.dkim.fmhosted.com."]
}

resource "aws_route53_record" "mail_dmarc" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "_dmarc.mads-hartmann.com"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=reject; sp=reject"]
}
