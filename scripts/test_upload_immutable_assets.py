import importlib.util
from hashlib import sha256
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('publisher', Path(__file__).with_name('upload-immutable-assets.py'))
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class PublisherTests(unittest.TestCase):
    def test_upload_contract_and_retention(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mime = {'webp': 'image/webp', 'avif': 'image/avif', 'woff2': 'font/woff2'}
            for extension in mime:
                contents = extension.encode()
                path = root / '_assets' / sha256(contents).hexdigest() / f'asset.{extension}'
                path.parent.mkdir(parents=True)
                path.write_bytes(contents)
            with patch.object(publisher.subprocess, 'run') as run:
                publisher.upload(root, 'test-bucket', mime, 'public,max-age=31536000,immutable')
                self.assertEqual(run.call_count, 3)
                for call in run.call_args_list:
                    args = call.args[0]
                    self.assertEqual(args[:3], ['aws', 's3', 'cp'])
                    extension = Path(args[3]).suffix[1:]
                    self.assertEqual(args[6], mime[extension])
                    self.assertEqual(args[8], 'public,max-age=31536000,immutable')
                    self.assertTrue(call.kwargs['check'])
                    self.assertNotIn('--delete', args)
            with patch.object(publisher.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'aws')):
                with self.assertRaises(subprocess.CalledProcessError):
                    publisher.upload(root, 'test-bucket', mime, 'public,max-age=31536000,immutable')

    def test_invalid_hash_fails_before_any_upload(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '_assets' / ('0' * 64) / 'bad.css'
            path.parent.mkdir(parents=True)
            path.write_text('body {}')
            with patch.object(publisher.subprocess, 'run') as run:
                with self.assertRaises(ValueError):
                    publisher.upload(directory, 'test-bucket', {}, 'immutable')
                run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
