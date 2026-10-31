"""Validate declared BER evidence; no hardware and no signal generation."""
import argparse
import copy
import json
import math
from datetime import datetime
from pathlib import Path


def integer(value):
    return isinstance(value, int) and not isinstance(value, bool)


def ranges(values):
    if not isinstance(values, list):
        raise ValueError("Ranges must be lists")
    pairs = []
    for pair in values:
        if not isinstance(pair, list) or len(pair) != 2:
            raise ValueError("Expected [start,end) pair")
        a, b = pair
        if not integer(a) or not integer(b) or not 0 <= a < b:
            raise ValueError("Invalid bit interval")
        pairs.append((a, b))
    ordered = sorted(pairs)
    if any(a[1] > b[0] for a, b in zip(ordered, ordered[1:])):
        raise ValueError("Overlapping intervals")
    return ordered


def overlap(left, right):
    return any(max(a, c) < min(b, d) for a, b in left for c, d in right)


def audit(data):
    lanes = data.get("lanes")
    if not isinstance(lanes, list) or not lanes or any(not isinstance(x, str) or not x.strip() for x in lanes) or len(set(lanes)) != len(lanes):
        raise ValueError("Explicit unique lane scope required")
    windows = data.get("windows")
    if not isinstance(windows, list) or not windows:
        raise ValueError("No windows")
    seen, used = set(), {}
    previous = None
    errors = bits = invalid = 0
    for w in windows:
        uid = w.get("id")
        if not isinstance(uid, str) or not uid or uid in seen:
            raise ValueError("Missing/duplicate window ID")
        seen.add(uid)
        t = datetime.fromisoformat(w["time"])
        if t.tzinfo is None or (previous is not None and t <= previous):
            raise ValueError("Times must include timezone and increase")
        previous = t
        if type(w.get("valid")) is not bool:
            raise ValueError("valid must be boolean")
        if not w["valid"]:
            if w.get("errors") is not None or w.get("bits") is not None or w.get("ber") is not None:
                raise ValueError("Invalid window must not masquerade as zero BER")
            invalid += 1
            continue
        for key in ("capture_id", "reference_id"):
            if not isinstance(w.get(key), str) or not w[key].strip():
                raise ValueError("Missing " + key)
        e, n = w["errors"], w["bits"]
        if not integer(e) or not integer(n) or not 0 <= e <= n or n <= 0:
            raise ValueError("Invalid error/bit counts")
        train, test = ranges(w["train_ranges"]), ranges(w["test_ranges"])
        if sum(b-a for a, b in test) != n or overlap(train, test):
            raise ValueError("Test denominator mismatch or training leakage")
        prior = used.setdefault(w["capture_id"], [])
        if overlap(prior, test):
            raise ValueError("Test bits counted twice")
        prior.extend(test)
        if "ber" in w:
            if isinstance(w["ber"], bool) or not isinstance(w["ber"], (int, float)) or not math.isfinite(w["ber"]) or not math.isclose(w["ber"], e/n, rel_tol=1e-9, abs_tol=1e-12):
                raise ValueError("Reported BER disagrees with counts")
        errors += e
        bits += n
    return {"lanes": lanes, "windows": len(windows), "valid": len(windows)-invalid,
            "invalid": invalid, "errors": errors, "bits": bits,
            "weighted_ber": errors/bits if bits else None,
            "scope": "declared test bits only; metadata does not prove reference authenticity"}


def self_test():
    def window(i, e, n):
        return dict(id=str(i), time="2026-10-31T12:00:%02d+08:00" % i,
                    valid=True, errors=e, bits=n, capture_id="synthetic"+str(i),
                    reference_id="synthetic-ref", train_ranges=[[0, 20]], test_ranges=[[20, 20+n]])
    data = {"lanes": ["TX0", "TX2"], "windows": [window(0, 1, 100), window(1, 45, 900),
            dict(id="2", time="2026-10-31T12:00:02+08:00", valid=False, errors=None, bits=None, ber=None)]}
    result = audit(data)
    assert result["bits"] == 1000 and result["errors"] == 46 and result["weighted_ber"] == 0.046 and result["invalid"] == 1
    def reject(edit):
        bad = copy.deepcopy(data)
        edit(bad)
        try:
            audit(bad)
        except (ValueError, KeyError, TypeError):
            return
        raise AssertionError("Fault was accepted")
    reject(lambda x: x["windows"][0].update(test_ranges=[[10, 110]]))
    reject(lambda x: x["windows"][0].update(ber=0.001))
    reject(lambda x: x["windows"][2].update(ber=0))
    reject(lambda x: x["windows"][1].update(capture_id="synthetic0"))
    reject(lambda x: x["windows"][1].update(id="0"))
    reject(lambda x: x["windows"][0].update(errors=101))
    reject(lambda x: x["windows"][0].update(reference_id=""))
    reject(lambda x: x["windows"][1].update(time="2026-10-31T12:00:00+08:00"))
    reject(lambda x: x["windows"][0].update(test_ranges=[[20, 70], [60, 110]]))
    reject(lambda x: x.update(lanes=[]))
    print("BER_AUDIT_SELF_TEST_PASS: weighted denominator, invalid retention, 10 rejected faults; synthetic only")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    elif args.input:
        print(json.dumps(audit(json.loads(args.input.read_text(encoding="utf-8-sig"))), ensure_ascii=False, indent=2, allow_nan=False))
    else:
        parser.error("Provide JSON input or --self-test")
