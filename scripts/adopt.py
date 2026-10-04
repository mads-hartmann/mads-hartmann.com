#!/usr/bin/env python3
"""Preview/import a reviewed manifest. AWS infrastructure is never applied here."""
import argparse, json, os, shlex, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('stack', choices=['kernel','shared','homepage','blog','uses'])
parser.add_argument('--include-dns', action='store_true', help='Import homepage A/AAAA only after the pre-DNS preview is verified')
parser.add_argument('--execute', action='store_true', help='Write the new remote state with terraform import')
parser.add_argument('--release-legacy', action='store_true', help='After verifying new ownership, remove transferred blog addresses from old state')
parser.add_argument('--var-file', action='append', default=[])
args = parser.parse_args()
os.umask(0o077)
manifest = json.loads((ROOT / f'.migration/{args.stack}-imports.json').read_text())
kernel_moves = {
    f'{kind}.master': f'{kind}.main' for kind in [
        'github_branch_default', 'github_repository_environment_deployment_policy', 'github_repository_ruleset'
    ]
}
def current_address(address):
    return kernel_moves.get(address, address) if args.stack == 'kernel' else address
for item in manifest:
    item['address'] = current_address(item['address'])
root = ROOT / ('terraform/kernel' if args.stack == 'kernel' else f'terraform/stacks/{args.stack}')
prefix = ['terraform', f'-chdir={root}']
variables = [f'-var-file={Path(file).resolve()}' for file in args.var_file]
if args.stack == 'homepage': variables += ['-var=publish_dns=false']

def run(command, capture=False):
    print(shlex.join(command))
    if args.execute:
        if capture:
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode:
                if command[-2:] == ['state','pull'] and 'No state file was found' in result.stderr: return '{"resources": []}'
                raise RuntimeError(result.stderr)
            return result.stdout
        return subprocess.check_call(command)

def resources(state):
    found = {}
    for resource in state.get('resources', []):
        if resource['mode'] != 'managed': continue
        address = (resource.get('module','') + '.' if resource.get('module') else '') + resource['type'] + '.' + resource['name']
        for instance in resource.get('instances', []):
            suffix = f'[{json.dumps(instance["index_key"])}]' if 'index_key' in instance else ''
            found[current_address(address + suffix)] = instance['attributes'].get('id')
    return found

run(prefix + ['init','-input=false','-lockfile=readonly','-backend-config=backend.hcl'])
if args.release_legacy:
    assert args.stack == 'blog', 'Only the blog transfers resources from the legacy production state'
    if args.execute:
        snapshot = run(prefix + ['state','pull'], capture=True)
        (ROOT / '.migration/blog-after-import.tfstate').write_text(snapshot)
        found = resources(json.loads(snapshot))
        assert all(found.get(item['address']) == item['id'] for item in manifest), 'Complete and verify all new imports first'
    old = ['terraform', f'-chdir={ROOT / "terraform/aws/production"}']
    run(old + ['init','-input=false'])
    if args.execute:
        snapshot = run(old + ['state','pull'], capture=True)
        (ROOT / '.migration/legacy-before-release.tfstate').write_text(snapshot)
    run(old + ['state','rm'] + [item['legacy_address'] for item in manifest if item['legacy_address']])
else:
    existing = resources(json.loads(run(prefix + ['state','pull'], capture=True))) if args.execute else {}
    for item in manifest:
        if args.stack == 'homepage' and item['address'].startswith('module.site.aws_route53_record.') and not args.include_dns: continue
        item_variables = [value for value in variables if value != '-var=publish_dns=false'] + (['-var=publish_dns=true'] if item['address'].startswith('module.site.aws_route53_record.') else ['-var=publish_dns=false']) if args.stack == 'homepage' else variables
        if item['address'] in existing:
            assert existing[item['address']] == item['id'], 'Existing state owns a different physical resource'
            continue
        run(prefix + ['import','-input=false'] + item_variables + [item['address'],item['id']])
