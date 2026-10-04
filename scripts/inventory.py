#!/usr/bin/env python3
"""Read-only AWS inventory; write private snapshots and reviewable import manifests.

Requires a human AWS session, AWS CLI and gh. Never applies or deletes resources.
"""
import json, os, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.migration'
ACCOUNT = '790804032123'
ZONE = 'Z18NSONI21UYAE'
CERT = 'arn:aws:acm:us-east-1:790804032123:certificate/344b3275-d3d8-4d12-81d3-eda18bf46967'
STATE_BUCKET = 'terraform-state-cloud-mads-hartmann-com'

def aws(*args, optional=()):
    result = subprocess.run(['aws', *args, '--output', 'json'], capture_output=True, text=True)
    if result.returncode:
        if any(f'({code})' in result.stderr for code in optional): return None
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else {}

def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n')

def main():
    os.umask(0o077)
    OUT.mkdir(mode=0o700, exist_ok=True)
    assert aws('sts', 'get-caller-identity')['Account'] == ACCOUNT, 'Wrong AWS account'
    # State snapshots contain old credentials; never print or commit these files.
    for bucket, name in [(STATE_BUCKET, 'legacy-production'), ('terraform-state-mads-hartmann-com', 'legacy-howto')]:
        aws('s3api', 'get-object', '--bucket', bucket, '--key', 'production.tfstate', str(OUT / f'{name}.tfstate'))
    state = json.loads((OUT / 'legacy-production.tfstate').read_text())
    distributions = aws('cloudfront', 'list-distributions').get('DistributionList', {}).get('Items', [])
    records = aws('route53', 'list-resource-record-sets', '--hosted-zone-id', ZONE)['ResourceRecordSets']
    certificate = aws('acm', 'describe-certificate', '--region', 'us-east-1', '--certificate-arn', CERT)['Certificate']
    save('cloudfront.json', distributions)
    save('dns.json', records)
    save('certificate.json', certificate)
    manifests = {stack: [] for stack in ['kernel', 'shared', 'homepage', 'blog', 'uses']}
    def add(stack, address, identifier, old=None):
        manifests[stack].append({'address': address, 'id': identifier, 'legacy_address': old})
    add('kernel', 'aws_s3_bucket.state', STATE_BUCKET)
    add('kernel', 'aws_s3_bucket_versioning.state', STATE_BUCKET)
    add('kernel', 'aws_s3_bucket_server_side_encryption_configuration.state', STATE_BUCKET)
    if aws('s3api', 'get-public-access-block', '--bucket', STATE_BUCKET, optional=['NoSuchPublicAccessBlockConfiguration']):
        add('kernel', 'aws_s3_bucket_public_access_block.state', STATE_BUCKET)
    if aws('s3api', 'get-bucket-policy', '--bucket', STATE_BUCKET, optional=['NoSuchBucketPolicy']):
        add('kernel', 'aws_s3_bucket_policy.state', STATE_BUCKET)
    oidc = f'arn:aws:iam::{ACCOUNT}:oidc-provider/token.actions.githubusercontent.com'
    if aws('iam', 'get-open-id-connect-provider', '--open-id-connect-provider-arn', oidc, optional=['NoSuchEntity']):
        add('kernel', 'aws_iam_openid_connect_provider.github', oidc)
    # Adopt the existing Production environment and keep main as the default branch.
    add('kernel', 'github_repository_environment.production', 'mads-hartmann.com:Production')
    add('kernel', 'github_branch_default.main', 'mads-hartmann.com')
    add('shared', 'aws_route53_zone.primary', ZONE)
    add('shared', 'aws_acm_certificate.primary', CERT)
    seen = set()
    for option in certificate.get('DomainValidationOptions', []):
        record = option.get('ResourceRecord')
        if record and record['Name'] not in seen:
            seen.add(record['Name'])
            add('shared', f'aws_route53_record.validation[{json.dumps(option["DomainName"].removeprefix("*."))}]', f'{ZONE}_{record["Name"]}_{record["Type"]}')
    save('shared.tfvars.json', {
        'certificate_domain': certificate['DomainName'],
        'certificate_alternative_names': [name for name in certificate['SubjectAlternativeNames'] if name != certificate['DomainName']],
        'legacy_certificate_validation_method': certificate['DomainValidationOptions'][0]['ValidationMethod']
    })
    preserved = {'aws_s3_bucket.bucket', 'aws_s3_bucket_public_access_block.public_access_block', 'aws_s3_bucket_policy.policy', 'aws_cloudfront_distribution.distribution', 'aws_route53_record.records'}
    blog_values = {'bucket_name': 'blog.mads-hartmann.com', 'region': 'us-east-1'}
    for resource in state.get('resources', []):
        if resource.get('module') != 'module.blog-mads-hartmann-com' or resource['mode'] != 'managed': continue
        name = f'{resource["type"]}.{resource["name"]}'
        for instance in resource['instances']:
            key = instance.get('index_key')
            old = f'{resource["module"]}.{name}' + (f'[{json.dumps(key)}]' if key is not None else '')
            attributes = instance['attributes']
            if name == 'aws_cloudfront_origin_access_identity.origin_access_identity':
                blog_values['legacy_oai_arn'] = attributes['iam_arn']
            if name not in preserved: continue
            address = 'module.site.' + name
            if key is not None: address += f'[{json.dumps("blog.mads-hartmann.com-"+key)}]'
            add('blog', address, attributes['id'], old)
    expected_blog = {
        'module.site.aws_s3_bucket.bucket',
        'module.site.aws_s3_bucket_public_access_block.public_access_block',
        'module.site.aws_s3_bucket_policy.policy',
        'module.site.aws_cloudfront_distribution.distribution',
        'module.site.aws_route53_record.records["blog.mads-hartmann.com-A"]',
        'module.site.aws_route53_record.records["blog.mads-hartmann.com-AAAA"]',
    }
    assert {item['address'] for item in manifests['blog']} == expected_blog, 'Unexpected legacy blog state; review before transferring ownership'
    blog_location = aws('s3api', 'get-bucket-location', '--bucket', blog_values['bucket_name'])
    blog_values['region'] = blog_location.get('LocationConstraint') or 'us-east-1'
    assert 'legacy_oai_arn' in blog_values, 'The legacy blog OAI must be inspected before adoption'
    save('blog.tfvars.json', blog_values)
    for stack, bucket in [('homepage', 'mads-hartmann.com'), ('uses', 'uses.mads-hartmann.com')]:
        location = aws('s3api', 'get-bucket-location', '--bucket', bucket, optional=['NoSuchBucket'])
        if location is not None:
            save(f'{stack}.tfvars.json', {'bucket_name': bucket, 'region': location.get('LocationConstraint') or 'us-east-1'})
            add(stack, 'module.site.aws_s3_bucket.bucket', bucket)
            if aws('s3api', 'get-public-access-block', '--bucket', bucket, optional=['NoSuchPublicAccessBlockConfiguration']): add(stack, 'module.site.aws_s3_bucket_public_access_block.public_access_block', bucket)
            if aws('s3api', 'get-bucket-policy', '--bucket', bucket, optional=['NoSuchBucketPolicy']): add(stack, 'module.site.aws_s3_bucket_policy.policy', bucket)
        domains = ['mads-hartmann.com', 'www.mads-hartmann.com'] if stack == 'homepage' else ['uses.mads-hartmann.com']
        matches = [d for d in distributions if set(d.get('Aliases', {}).get('Items', [])) & set(domains)]
        assert len(matches) <= 1, f'Multiple {stack} distributions need a manual consolidation decision'
        if matches:
            add(stack, 'module.site.aws_cloudfront_distribution.distribution', matches[0]['Id'])
            identities = [origin.get('S3OriginConfig', {}).get('OriginAccessIdentity') for origin in matches[0].get('Origins', {}).get('Items', [])]
            identities = [identity for identity in identities if identity]
            if identities:
                assert len(identities) == 1, 'Review multiple origin identities'
                values_file = OUT / f'{stack}.tfvars.json'
                values = json.loads(values_file.read_text()) if values_file.exists() else {}
                values['legacy_oai_arn'] = 'arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ' + identities[0].split('/')[-1]
                save(f'{stack}.tfvars.json', values)
        for record in records:
            domain = record['Name'].rstrip('.')
            if domain not in domains: continue
            if record['Type'] in ['A', 'AAAA']: add(stack, f'module.site.aws_route53_record.records[{json.dumps(domain+"-"+record["Type"])}]', f'{ZONE}_{record["Name"]}_{record["Type"]}')
            elif stack == 'homepage' and record['Type'] == 'CNAME':
                assert record['ResourceRecords'] == [{'Value': 'cname.vercel-dns.com.'}], 'Review changed Vercel CNAME'
                add(stack, 'aws_route53_record.legacy_www[0]', f'{ZONE}_{record["Name"]}_CNAME')
                save('homepage-dns.tfvars.json', {'legacy_www_ttl': record['TTL']})
    for stack, imports in manifests.items(): save(f'{stack}-imports.json', imports)
    print(f'Inventory saved privately in {OUT}. Review docs/migration.md before importing.')

if __name__ == '__main__': main()
