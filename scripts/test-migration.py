#!/usr/bin/env python3
"""Exercise migration safeguards without AWS credentials or remote state writes."""
import contextlib, importlib.util, io, json, os, shutil, subprocess, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

class AdoptionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        (self.root / 'scripts').mkdir()
        shutil.copy(ROOT / 'scripts/adopt.py', self.root / 'scripts/adopt.py')
        (self.root / '.migration').mkdir()
        self.item = {'address':'module.site.aws_s3_bucket.bucket','id':'blog.mads-hartmann.com','legacy_address':'module.blog-mads-hartmann-com.aws_s3_bucket.bucket'}
        (self.root / '.migration/blog-imports.json').write_text(json.dumps([self.item]))
        self.fake = self.root / 'terraform'
        self.fake.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
with open(os.environ['COMMAND_LOG'],'a') as log: log.write(json.dumps(sys.argv[1:])+'\\n')
if sys.argv[-2:] == ['state','pull']:
 if os.environ.get('EMPTY_STATE') == 'true':
  print('No state file was found!',file=sys.stderr);sys.exit(1)
 print(json.dumps({'resources':[{'module':'module.site','mode':'managed','type':'aws_s3_bucket','name':'bucket','instances':[{'attributes':{'id':os.environ['BUCKET_ID']}}]}]}))
''')
        self.fake.chmod(0o755)
        self.environment = dict(os.environ, PATH=str(self.root)+os.pathsep+os.environ['PATH'], COMMAND_LOG=str(self.root/'commands'), BUCKET_ID=self.item['id'])
    def tearDown(self): self.directory.cleanup()
    def run_adopt(self,*args):
        return subprocess.run(['python3',str(self.root/'scripts/adopt.py'),*args],env=self.environment,capture_output=True,text=True)
    def commands(self):
        path=self.root/'commands'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
    def test_release_requires_verified_new_owner(self):
        self.environment['BUCKET_ID']='wrong-bucket'
        result=self.run_adopt('blog','--execute','--release-legacy')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(any('rm' in command for command in self.commands()))
    def test_release_forgets_only_transferred_addresses(self):
        result=self.run_adopt('blog','--execute','--release-legacy')
        self.assertEqual(result.returncode,0,result.stderr)
        removed=[command for command in self.commands() if 'rm' in command]
        self.assertEqual(len(removed),1)
        self.assertEqual(removed[0][-1],self.item['legacy_address'])
        self.assertTrue((self.root/'.migration/legacy-before-release.tfstate').exists())
    def test_empty_state_can_be_imported(self):
        self.environment['EMPTY_STATE']='true'
        result=self.run_adopt('blog','--execute')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue(any('import' in command for command in self.commands()))
    def test_preview_never_runs_terraform(self):
        result=self.run_adopt('blog')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(self.commands(),[])
    def test_homepage_defers_alias_imports_during_preview(self):
        item=dict(self.item,address='module.site.aws_route53_record.records["mads-hartmann.com-A"]',id='ZEXAMPLE_mads-hartmann.com_A',legacy_address=None)
        (self.root/'.migration/homepage-imports.json').write_text(json.dumps([item]))
        result=self.run_adopt('homepage')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertNotIn(' import ',result.stdout)
        result=self.run_adopt('homepage','--include-dns')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('-var=publish_dns=true',result.stdout)

class InventoryTests(unittest.TestCase):
    def test_inventory_hides_secrets_and_maps_real_addresses(self):
        self.check_inventory('DNS')
    def test_email_certificate_needs_no_validation_record_import(self):
        self.check_inventory('EMAIL')
    def check_inventory(self, method):
        spec=importlib.util.spec_from_file_location('inventory',ROOT/'scripts/inventory.py')
        inventory=importlib.util.module_from_spec(spec);spec.loader.exec_module(inventory)
        with tempfile.TemporaryDirectory() as directory:
            inventory.OUT=Path(directory)/'.migration'
            old={'resources':[
                {'module':'module.blog-mads-hartmann-com','mode':'managed','type':'aws_s3_bucket','name':'bucket','instances':[{'attributes':{'id':'blog.mads-hartmann.com'}}]},
                {'module':'module.blog-mads-hartmann-com','mode':'managed','type':'aws_cloudfront_origin_access_identity','name':'origin_access_identity','instances':[{'attributes':{'iam_arn':'arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity EOLD'}}]},
                {'module':'module.blog-mads-hartmann-com','mode':'managed','type':'aws_iam_access_key','name':'access_key','instances':[{'attributes':{'id':'test-key','secret':'MUST_NOT_APPEAR'}}]}
            ]}
            for kind, name, identifier, key in [
                ('aws_s3_bucket_public_access_block','public_access_block','blog.mads-hartmann.com',None),
                ('aws_s3_bucket_policy','policy','blog.mads-hartmann.com',None),
                ('aws_cloudfront_distribution','distribution','EDISTRIBUTION',None),
                ('aws_route53_record','records','ZEXAMPLE_blog_A','A'),
                ('aws_route53_record','records','ZEXAMPLE_blog_AAAA','AAAA')
            ]:
                instance={'attributes':{'id':identifier}}
                if key:instance['index_key']=key
                old['resources'].append({'module':'module.blog-mads-hartmann-com','mode':'managed','type':kind,'name':name,'instances':[instance]})
            def fake_aws(*args,**kwargs):
                if args[:2]==('sts','get-caller-identity'):return {'Account':inventory.ACCOUNT}
                if args[:2]==('s3api','get-object'):Path(args[-1]).write_text(json.dumps(old));return {}
                if args[:2]==('cloudfront','list-distributions'):return {'DistributionList':{}}
                if args[:2]==('route53','list-resource-record-sets'):return {'ResourceRecordSets':[]}
                if args[:2]==('acm','describe-certificate'):
                    options=[dict(DomainName=name,ValidationMethod=method) for name in ['*.mads-hartmann.com','mads-hartmann.com']]
                    if method=='DNS':
                        for option in options:option['ResourceRecord']={'Name':'_proof.mads-hartmann.com.','Type':'CNAME','Value':'_proof.acm-validations.aws.'}
                    return {'Certificate':{'DomainName':'*.mads-hartmann.com','SubjectAlternativeNames':['*.mads-hartmann.com','mads-hartmann.com'],'DomainValidationOptions':options}}
                if args[:2]==('s3api','get-bucket-location') and '--bucket' in args and args[args.index('--bucket')+1]=='blog.mads-hartmann.com':return {'LocationConstraint':None}
                if kwargs.get('optional'):return None
                raise AssertionError(args)
            inventory.aws=fake_aws
            output=io.StringIO()
            old_mask=os.umask(0o077)
            try:
                with contextlib.redirect_stdout(output):inventory.main()
            finally:os.umask(old_mask)
            self.assertNotIn('MUST_NOT_APPEAR',output.getvalue())
            manifests=''.join(path.read_text() for path in inventory.OUT.glob('*imports.json'))
            self.assertNotIn('MUST_NOT_APPEAR',manifests)
            self.assertIn('module.site.aws_s3_bucket.bucket',manifests)
            shared=json.loads((inventory.OUT/'shared-imports.json').read_text())
            self.assertEqual(sum(item['address'].startswith('aws_route53_record.validation[') for item in shared),1 if method=='DNS' else 0)
            values=json.loads((inventory.OUT/'shared.tfvars.json').read_text())
            self.assertEqual(values['legacy_certificate_validation_method'],method)
            self.assertEqual(inventory.OUT.stat().st_mode & 0o777,0o700)

if __name__=='__main__':unittest.main()
