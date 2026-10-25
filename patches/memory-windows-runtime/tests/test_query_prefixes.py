"""Execute the query-formatting boundary without a live profile or provider."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('memory_query_patch', HERE / 'apply.py')
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)


class QueryFormatting(unittest.TestCase):
    def test_actual_parser_search_and_transport(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'canonical.mjs'
            target.write_bytes(patcher.build_canonical(patcher.BACKUP.read_bytes()))
            result = subprocess.run(
                ['node', str(HERE / 'tests/test-query-formatting.mjs'), str(target)],
                capture_output=True, text=True, encoding='utf-8', errors='replace',
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
