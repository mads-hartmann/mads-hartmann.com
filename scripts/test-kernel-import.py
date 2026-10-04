#!/usr/bin/env python3
"""Exercise Terraform's import evaluator with the kernel's real variable-map expression.

Use built-in terraform_data IDs in place of IAM ARNs, leaving those values unknown
until apply. This reproduces bootstrap import behavior without AWS or GitHub access.
"""
import json, os, re, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'terraform/kernel/main.tf').read_text()
identities = source.split('resource "aws_s3_bucket" "state"')[0]
variables = re.search(r'(?ms)^locals \{\n  github_variables = .*?^\}\n', source)
assert variables, 'Kernel GitHub-variable expression not found'
variables = variables.group(0).replace('aws_iam_role.github', 'terraform_data.github').replace('.arn', '.id')
fixture = identities + variables + '''
variable "account_id" { default = "790804032123" }
variable "state_bucket" { default = "test-state-bucket" }
variable "deploy_enabled" { default = false }
resource "terraform_data" "state" {}
resource "terraform_data" "github" {
  for_each = local.identities
  input = each.key
}
resource "terraform_data" "deployment" {
  for_each = local.github_variables
  input = each.value
}
'''

with tempfile.TemporaryDirectory(prefix='kernel-import-test-') as directory:
    root = Path(directory)
    (root / 'main.tf').write_text(fixture)
    environment = dict(os.environ, TF_DATA_DIR=str(root / '.terraform'), TF_WORKSPACE='default', TF_IN_AUTOMATION='true')
    for command in [
        ['terraform', 'init', '-backend=false', '-input=false', '-no-color'],
        ['terraform', 'import', '-input=false', '-no-color', 'terraform_data.state', 'import-probe'],
    ]:
        result = subprocess.run(command, cwd=root, env=environment, text=True, capture_output=True)
        if result.returncode:
            print(result.stdout + result.stderr)
            raise SystemExit(result.returncode)
    state = json.loads((root / 'terraform.tfstate').read_text())
    assert [(resource['type'], resource['name']) for resource in state['resources']] == [('terraform_data', 'state')], 'Bootstrap import must not apply the role or variable resources'
print('Kernel bootstrap import passes with role values still unknown; only the local probe was imported.')
