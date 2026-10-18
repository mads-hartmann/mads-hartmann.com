import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("manifest", Path(__file__).with_name("site-manifest.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ContentIdentityTest(unittest.TestCase):
    def test_content_not_metadata_or_location(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first, second = root / "a", root / "b"
            first.write_bytes(b"same output")
            second.write_bytes(b"same output")
            os.utime(first, (1, 1))
            os.utime(second, (1000, 1000))
            digest = module.digest_files([("index.html", first)])
            self.assertEqual(digest, module.digest_files([("index.html", second)]))
            self.assertNotEqual(digest, module.digest_files([("renamed.html", first)]))
            self.assertNotEqual(digest, module.digest_files([]))
            second.write_bytes(b"new output")
            self.assertNotEqual(digest, module.digest_files([("index.html", second)]))

    def test_file_order_and_additions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            a, b = root / "a", root / "b"
            a.write_bytes(b"a")
            b.write_bytes(b"b")
            files = [("a", a), ("b", b)]
            self.assertEqual(module.digest_files(files), module.digest_files(reversed(files)))
            self.assertNotEqual(module.digest_files(files), module.digest_files(files[:1]))


if __name__ == "__main__":
    unittest.main()
