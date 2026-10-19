# Adopt the existing Fastmail RRsets before changing SPF. Keeping these blocks
# is safe after adoption: Terraform skips imports already present in state.
# This is the existing production zone, not a newly created zone ID; import IDs
# must be known at plan time, including in backend-free tests.
import {
  to = aws_route53_record.mail_mx
  id = "Z18NSONI21UYAE_mads-hartmann.com_MX"
}

import {
  to = aws_route53_record.mail_spf
  id = "Z18NSONI21UYAE_mads-hartmann.com_TXT"
}

import {
  for_each = toset(["fm1", "fm2", "fm3"])
  to       = aws_route53_record.mail_dkim[each.key]
  id       = "Z18NSONI21UYAE_${each.key}._domainkey.mads-hartmann.com_CNAME"
}
