#!/usr/bin/env python3
"""Test both formula inputs without GitHub or modifying the real formula."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
STUB = r'''
import json, os, pathlib, sys
args = sys.argv[1:]
url = next(a for a in args if a.startswith("https://"))
with pathlib.Path(os.environ["CALLS"]).open("a") as log:
    log.write(url + "\n")
output = pathlib.Path(args[args.index("-o") + 1])
if url.endswith("/releases/latest"):
    output.write_text(json.dumps({"tag_name": os.environ.get("RELEASE_TAG", "3.12"),
                                  "draft": bool(os.environ.get("DRAFT")), "prerelease": False}))
else:
    if os.environ.get("MISSING_TAG"):
        sys.exit(22)
    output.write_bytes(b"source from tag")
'''


class BumpTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        (self.work / "scripts").mkdir()
        (self.work / "Formula").mkdir()
        shutil.copyfile(ROOT / "scripts/bump-mistserver.sh", self.work / "scripts/bump-mistserver.sh")
        self.formula = self.work / "Formula/mistserver.rb"
        self.formula.write_text('class Mistserver < Formula\n  url "old-url"\n  version "3.11"\n  sha256 "old-sha"\nend\n')
        tools = self.work / "bin"
        tools.mkdir()
        curl = tools / "curl"
        curl.write_text("#!" + sys.executable + "\n" + STUB)
        curl.chmod(0o755)
        self.env = dict(os.environ, PATH=str(tools) + ":" + os.environ["PATH"], CALLS=str(self.work / "calls"))

    def run_bump(self, *args):
        return subprocess.run(["bash", str(self.work / "scripts/bump-mistserver.sh"), *args],
                              env=self.env, capture_output=True, text=True)

    def calls(self):
        path = self.work / "calls"
        return path.read_text().splitlines() if path.exists() else []

    def test_tag_updates_without_release_lookup(self):
        result = self.run_bump("3.12")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls(), ["https://github.com/DDVTECH/mistserver/archive/refs/tags/3.12.tar.gz"])
        self.assertIn('version "3.12"', self.formula.read_text())
        self.assertIn(hashlib.sha256(b"source from tag").hexdigest(), self.formula.read_text())

    def test_nightly_uses_published_release(self):
        result = self.run_bump()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.calls()[0].endswith("/releases/latest"))
        self.assertIn('version "3.12"', self.formula.read_text())

    def test_nightly_does_not_downgrade_newer_tag_formula(self):
        self.formula.write_text(self.formula.read_text().replace('version "3.11"', 'version "3.13"'))
        original = self.formula.read_bytes()
        result = self.run_bump()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.formula.read_bytes(), original)
        self.assertEqual(len(self.calls()), 1)

    def test_invalid_and_development_tags_rejected(self):
        for tag in ("bad..tag", "two words", "", "development"):
            with self.subTest(tag=tag):
                self.assertNotEqual(self.run_bump(tag).returncode, 0)
                self.assertEqual(self.calls(), [])
                self.assertIn('version "3.11"', self.formula.read_text())

    def test_explicit_unusual_tag_updates_without_release_lookup(self):
        for tag in ("libmist-8.0.3-LTS", "release/3.12-beta1", "EFG_T1_20260212B_AVREFACTOR"):
            with self.subTest(tag=tag):
                result = self.run_bump(tag)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('version "' + tag + '"', self.formula.read_text())
                self.assertEqual(self.calls()[-1], "https://github.com/DDVTECH/mistserver/archive/refs/tags/" + quote(tag, safe="") + ".tar.gz")
                self.assertFalse(any("/releases" in url for url in self.calls()))

    def test_nightly_does_not_replace_incomparable_explicit_tag(self):
        self.assertEqual(self.run_bump("libmist-8.0.3-LTS").returncode, 0)
        original = self.formula.read_bytes()
        self.assertEqual(self.run_bump().returncode, 0)
        self.assertEqual(self.formula.read_bytes(), original)
        self.assertTrue(self.calls()[-1].endswith("/releases/latest"))

    def test_nightly_does_not_replace_distinct_tag_with_equivalent_version(self):
        self.assertEqual(self.run_bump("v3.12.0").returncode, 0)
        original = self.formula.read_bytes()
        self.assertEqual(self.run_bump().returncode, 0)
        self.assertEqual(self.formula.read_bytes(), original)

    def test_late_numeric_dispatch_does_not_downgrade(self):
        self.assertEqual(self.run_bump("3.13").returncode, 0)
        original = self.formula.read_bytes()
        self.assertEqual(self.run_bump("3.12").returncode, 0)
        self.assertEqual(self.formula.read_bytes(), original)
        self.assertEqual(len(self.calls()), 1)

    def test_tag_escaping_does_not_inject_ruby(self):
        tag = 'release/3.12"#{raise("unsafe")}'
        result = self.run_bump(tag)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.run_bump(tag).returncode, 0)
        # Evaluate the generated formula with inert Homebrew DSL methods.
        ruby = 'class Formula; def self.url(x); end; def self.sha256(x); end; def self.version(x); puts x; end; end; load ARGV[0]'
        evaluated = subprocess.run(["ruby", "-e", ruby, str(self.formula)], capture_output=True, text=True)
        self.assertEqual(evaluated.returncode, 0, evaluated.stderr)
        self.assertEqual(evaluated.stdout.strip(), tag)

    def test_unrelated_cask_is_untouched(self):
        cask = self.work / "Casks/misttray.rb"
        cask.parent.mkdir()
        cask.write_text("existing signed tray version")
        self.assertEqual(self.run_bump("3.12").returncode, 0)
        self.assertEqual(cask.read_text(), "existing signed tray version")

    def test_v_prefix_keeps_source_tag_and_normalizes_formula_version(self):
        result = self.run_bump("v3.12.1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('version "3.12.1"', self.formula.read_text())
        self.assertTrue(self.calls()[0].endswith("/v3.12.1.tar.gz"))

    def test_missing_tag_does_not_change_formula(self):
        self.env["MISSING_TAG"] = "1"
        original = self.formula.read_bytes()
        self.assertNotEqual(self.run_bump("3.12").returncode, 0)
        self.assertEqual(self.formula.read_bytes(), original)

    def test_draft_release_does_not_change_formula(self):
        self.env["DRAFT"] = "1"
        original = self.formula.read_bytes()
        self.assertNotEqual(self.run_bump().returncode, 0)
        self.assertEqual(self.formula.read_bytes(), original)

    def test_repeat_tag_update_is_idempotent(self):
        self.assertEqual(self.run_bump("3.12").returncode, 0)
        original = self.formula.read_bytes()
        self.assertEqual(self.run_bump("3.12").returncode, 0)
        self.assertEqual(self.formula.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
