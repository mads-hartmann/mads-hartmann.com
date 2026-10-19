mock_provider "aws" {}

# Import blocks need explicit resource overrides with a mock provider.
override_resource {
  target          = aws_route53_record.mail_mx
  override_during = plan
}
override_resource {
  target          = aws_route53_record.mail_spf
  override_during = plan
}
override_resource {
  target          = aws_route53_record.mail_dkim
  override_during = plan
}

# Production already has a hosted zone before these records are imported.
run "existing_zone" {
  command = apply
  plan_options { target = [aws_route53_zone.primary] }
}

run "email_authentication" {
  command = plan

  assert {
    condition = (
      aws_route53_record.mail_spf.name == aws_route53_zone.primary.name &&
      aws_route53_record.mail_spf.type == "TXT" &&
      aws_route53_record.mail_spf.records == toset(["v=spf1 include:spf.messagingengine.com -all"]) &&
      aws_route53_record.mail_dmarc.name == "_dmarc.mads-hartmann.com" &&
      aws_route53_record.mail_dmarc.type == "TXT" &&
      aws_route53_record.mail_dmarc.records == toset(["v=DMARC1; p=reject; sp=reject"])
    )
    error_message = "Only Fastmail may send, and DMARC must reject unauthenticated mail for the domain and its subdomains."
  }

  assert {
    condition = (
      aws_route53_record.mail_mx.name == aws_route53_zone.primary.name &&
      aws_route53_record.mail_mx.type == "MX" &&
      aws_route53_record.mail_mx.records == toset(["10 in1-smtp.messagingengine.com.", "20 in2-smtp.messagingengine.com."])
    )
    error_message = "Incoming Fastmail delivery must retain both MX hosts and their priorities."
  }

  assert {
    condition = (
      toset(keys(aws_route53_record.mail_dkim)) == toset(["fm1", "fm2", "fm3"]) &&
      alltrue([for selector, record in aws_route53_record.mail_dkim :
        record.name == "${selector}._domainkey.mads-hartmann.com" &&
        record.type == "CNAME" &&
        record.records == toset(["${selector}.mads-hartmann.com.dkim.fmhosted.com."])
      ])
    )
    error_message = "All three Fastmail DKIM delegations must remain available for key rotation."
  }
}
