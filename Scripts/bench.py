#!/usr/bin/env python3
"""Median-of-N timings of Snagless runs."""
import argparse
import json
import re
import statistics
import subprocess
import time

TIMING = re.compile(
    r"timing: list ([\d.]+) ms, parse\+summarize ([\d.]+) ms, graph ([\d.]+) ms, total ([\d.]+) ms"
)
KEYS = ["list", "parse", "graph", "total"]


def run_once(binary, target):
    start = time.perf_counter()
    result = subprocess.run(
        [binary, "--timing", "--previews", "warning", target], capture_output=True, text=True
    )
    wall = (time.perf_counter() - start) * 1000
    match = TIMING.search(result.stderr)
    if not match:
        raise SystemExit(f"no timing line from {target}: {result.stderr[-500:]}")
    run = {key: float(match.group(index + 1)) for index, key in enumerate(KEYS)}
    run["wall"] = wall
    return run


def bench(binary, target, runs):
    measured = [run_once(binary, target) for _ in range(runs)]
    return {"target": target} | {key: statistics.median(run[key] for run in measured) for key in KEYS + ["wall"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("targets", nargs="+")
    args = parser.parse_args()
    print(json.dumps([bench(args.binary, target, args.runs) for target in args.targets], indent=1))
