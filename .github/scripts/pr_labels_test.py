#!/usr/bin/env python3
import unittest

from pr_labels import labels_for


class LabelsForTest(unittest.TestCase):
    def test_feature(self):
        self.assertEqual(labels_for("feat: add strm generator", ""), ["enhancement"])
        self.assertEqual(
            labels_for("feat(strm): walk directories", ""),
            ["enhancement"],
        )
        self.assertEqual(labels_for("feature: export files", ""), ["enhancement"])

    def test_fix_and_docs(self):
        self.assertEqual(labels_for("fix: handle empty token", ""), ["bug"])
        self.assertEqual(labels_for("fix(client): retry 502", ""), ["bug"])
        self.assertEqual(labels_for("docs: describe config", ""), ["documentation"])

    def test_breaking_title_and_footer(self):
        self.assertEqual(
            labels_for("feat!: drop --legacy", ""),
            ["breaking-change", "enhancement"],
        )
        self.assertEqual(
            labels_for("fix(api)!: reject v1 payloads", ""),
            ["breaking-change", "bug"],
        )
        self.assertEqual(
            labels_for(
                "fix: rename field",
                "Details.\n\nBREAKING CHANGE: clients must send the new field.\n",
            ),
            ["breaking-change", "bug"],
        )

    def test_unclassified_titles(self):
        self.assertEqual(labels_for("chore: update dependencies", ""), [])
        self.assertEqual(labels_for("refactor: extract strm", ""), [])
        self.assertEqual(labels_for("add strm generator", ""), [])

    def test_breaking_footer_without_conventional_title(self):
        self.assertEqual(
            labels_for("rename the config file", "BREAKING CHANGE: path moved\n"),
            ["breaking-change"],
        )
        self.assertEqual(
            labels_for("refactor!: change the config path", ""),
            ["breaking-change"],
        )


if __name__ == "__main__":
    unittest.main()
