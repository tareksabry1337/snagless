#!/usr/bin/env python3
"""Run Snagless on a generated app and score it against expected.json."""
import json
import os
import re
import subprocess
import sys

DIAGNOSTIC = re.compile(r"^(.*?):(\d+):(\d+): (error|warning): .* without `([^`]+)`;")


def score(binary, app):
    expected = json.load(open(os.path.join(app, "expected.json")))
    truth = {(v["file"], v["line"], v["type"]): v["kind"] for v in expected["violations"]}
    run = subprocess.run([binary, "--previews", "error", app], capture_output=True, text=True)
    found = set()
    prefixes = [app.rstrip("/") + "/", os.path.realpath(app) + "/"]
    for line in run.stdout.splitlines():
        match = DIAGNOSTIC.match(line)
        if not match:
            continue
        path = match.group(1)
        for prefix in prefixes:
            if path.startswith(prefix):
                path = path[len(prefix):]
                break
        found.add((path, int(match.group(2)), match.group(5)))
    true_positives = found & set(truth)
    precision = len(true_positives) / len(found) if found else 1.0
    recall = len(true_positives) / len(truth) if truth else 1.0
    by_kind = {}
    for key, kind in truth.items():
        hit, total = by_kind.get(kind, (0, 0))
        by_kind[kind] = (hit + (key in found), total + 1)
    return {
        "app": app,
        "expected": len(truth),
        "reported": len(found),
        "true_positives": len(true_positives),
        "precision": precision,
        "recall": recall,
        "recall_by_root_kind": {k: f"{h}/{t}" for k, (h, t) in sorted(by_kind.items())},
        "false_positives": sorted(found - set(truth))[:10],
        "false_negatives": sorted(set(truth) - found)[:10],
        "summary": run.stderr.strip().splitlines()[-1] if run.stderr.strip() else "",
    }


if __name__ == "__main__":
    binary = sys.argv[1]
    for app in sys.argv[2:]:
        print(json.dumps(score(binary, app), indent=1))
