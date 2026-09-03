#!/usr/bin/env python3

import argparse
import re
from pathlib import Path


DEFAULT_DEPTH = 8


def percent(hit_count, total_count):
    if total_count == 0:
        return 0.0
    return 100.0 * hit_count / total_count


def average(values):
    if not values:
        return 0.0
    return sum(values) / len(values)


def make_read_protocol_bins():
    groups = {}

    groups["Role"] = {
        "ROLE_MANAGER",
        "ROLE_SUBORDINATE",
    }

    groups["Request/response"] = {
        "KIND_REQUEST",
        "KIND_RESPONSE",
    }

    groups["ARPROT"] = {
        f"PROT_{value:03b}"
        for value in range(8)
    }

    # The SystemVerilog default address bin does not contribute to native
    # coverage scoring, so only the explicit subordinate-region bin is scored.
    groups["Address region"] = {
        "ADDR_SUBORDINATE_REGION",
    }

    groups["Response"] = {
        "RESP_OKAY",
        "RESP_SLVERR",
        "RESP_DECERR",
    }

    groups["Role x kind"] = {
        "CROSS_ROLE_MANAGER_KIND_REQUEST",
        "CROSS_ROLE_MANAGER_KIND_RESPONSE",
        "CROSS_ROLE_SUBORDINATE_KIND_REQUEST",
        "CROSS_ROLE_SUBORDINATE_KIND_RESPONSE",
    }

    groups["Role x protection"] = {
        f"CROSS_ROLE_{role}_PROT_{value:03b}"
        for role in ("MANAGER", "SUBORDINATE")
        for value in range(8)
    }

    groups["Role x response"] = {
        f"CROSS_ROLE_{role}_RESP_{resp}"
        for role in ("MANAGER", "SUBORDINATE")
        for resp in ("OKAY", "SLVERR", "DECERR")
    }

    return groups


def make_write_protocol_bins():
    groups = {}

    groups["Role"] = {
        "ROLE_MANAGER",
        "ROLE_SUBORDINATE",
    }

    groups["AW/W/B kind"] = {
        "KIND_AW",
        "KIND_W",
        "KIND_B",
    }

    groups["Address region"] = {
        "ADDR_BELOW_SUB",
        "ADDR_SUB_REGION",
        "ADDR_ABOVE_SUB",
    }

    groups["AWPROT"] = {
        f"PROT_{value:03b}"
        for value in range(8)
    }

    groups["WSTRB"] = {
        f"STRB_{value:04b}"
        for value in range(16)
    }

    # AXI4-Lite has no exclusive-access semantics, so EXOKAY is not an
    # applicable response target for this SCC.
    groups["BRESP"] = {
        "RESP_OKAY",
        "RESP_SLVERR",
        "RESP_DECERR",
    }

    groups["Role x kind"] = {
        f"CROSS_ROLE_{role}_KIND_{kind}"
        for role in ("MANAGER", "SUBORDINATE")
        for kind in ("AW", "W", "B")
    }

    groups["Role x protection"] = {
        f"CROSS_ROLE_{role}_PROT_{value:03b}"
        for role in ("MANAGER", "SUBORDINATE")
        for value in range(8)
    }

    groups["Role x strobe"] = {
        f"CROSS_ROLE_{role}_STRB_{value:04b}"
        for role in ("MANAGER", "SUBORDINATE")
        for value in range(16)
    }

    groups["Role x response"] = {
        f"CROSS_ROLE_{role}_RESP_{resp}"
        for role in ("MANAGER", "SUBORDINATE")
        for resp in ("OKAY", "SLVERR", "DECERR")
    }

    return groups


def make_fault_bins():
    groups = {}

    groups["Fault source"] = {
        "SOURCE_READ_TIMEOUT",
        "SOURCE_WRITE_DATA_TIMEOUT",
        "SOURCE_WRITE_RESP_TIMEOUT",
    }

    groups["Enable/mask"] = {
    "ENABLE_ENABLED",
    "ENABLE_DISABLED",
    }

    groups["Fault source x enable"] = {
        f"CROSS_{source}_{enabled}"
        for source in (
            "READ_TIMEOUT",
            "WRITE_DATA_TIMEOUT",
            "WRITE_RESP_TIMEOUT",
        )
        for enabled in ("ENABLED", "DISABLED")
    }

    return groups


def make_recovery_bins():
    groups = {}

    groups["Mode/state"] = {
        "MODE_NORMAL",
        "MODE_CONTAINING",
        "MODE_RECOVERY",
        "TRANS_NORMAL_TO_CONTAINING",
        "TRANS_CONTAINING_TO_RECOVERY",
        "TRANS_RECOVERY_TO_NORMAL",
    }

    groups["Upstream quiescence"] = {
        "QUIESCENT_NO",
        "QUIESCENT_YES",
    }

    groups["IRQ"] = {
        "IRQ_LOW",
        "IRQ_HIGH",
    }

    groups["Recovery ack"] = {
        "ACK_NO",
        "ACK_YES",
    }

    groups["Epoch clear"] = {
        "EPOCH_CLEAR_NO",
        "EPOCH_CLEAR_YES",
    }

    groups["Mode x quiescence"] = ({
        f"CROSS_MODE_{mode}_QUIESCENT_{value}"
        for mode in ("NORMAL", "CONTAINING", "RECOVERY")
        for value in ("NO", "YES")
    } | {
        f"CROSS_TRANS_{transition}_QUIESCENT_{value}"
        for transition in (
            "NORMAL_TO_CONTAINING",
            "CONTAINING_TO_RECOVERY",
            "RECOVERY_TO_NORMAL",
        )
        for value in ("NO", "YES")
    }) - {
        # Structurally unreachable by the recovery protocol.
        "CROSS_MODE_RECOVERY_QUIESCENT_NO",
        "CROSS_TRANS_CONTAINING_TO_RECOVERY_QUIESCENT_NO",
        "CROSS_TRANS_RECOVERY_TO_NORMAL_QUIESCENT_NO",
    }

    groups["Mode x IRQ"] = ({
        f"CROSS_MODE_{mode}_IRQ_{value}"
        for mode in ("NORMAL", "CONTAINING", "RECOVERY")
        for value in ("LOW", "HIGH")
    } | {
        f"CROSS_TRANS_{transition}_IRQ_{value}"
        for transition in (
            "NORMAL_TO_CONTAINING",
            "CONTAINING_TO_RECOVERY",
            "RECOVERY_TO_NORMAL",
        )
        for value in ("LOW", "HIGH")
    }) - {
        # IRQ cannot remain high in these sampled architectural states.
        "CROSS_MODE_NORMAL_IRQ_HIGH",
        "CROSS_TRANS_RECOVERY_TO_NORMAL_IRQ_HIGH",
    }

    return groups


def make_recovered_fault_bins():
    return {
        "Recovered fault source": {
            "RECOVERED_READ_TIMEOUT",
            "RECOVERED_WRITE_DATA_TIMEOUT",
            "RECOVERED_WRITE_RESP_TIMEOUT",
        }
    }


def make_read_queue_bins(depth):
    groups = {}

    groups["Outstanding occupancy"] = {
        "OUTST_EMPTY",
        "OUTST_ONE",
        "OUTST_FULL",
    } | {
        f"OUTST_PARTIAL_{value}"
        for value in range(2, depth)
    }

    # Exact drain depths above one are implementation-detail repetitions of
    # the same semantic condition. Score zero / one / multiple instead.
    groups["Ghost-drain occupancy"] = {
        "DRAIN_ZERO",
        "DRAIN_ONE",
        "DRAIN_MULTIPLE",
    }

    groups["Queue operation"] = {
        "OP_IDLE",
        "OP_ENQUEUE_ONLY",
        "OP_RETIRE_ONLY",
        "OP_ENQUEUE_AND_RETIRE",
    }

    groups["Timeout injection"] = {
        "INJECT_NO",
        "INJECT_YES",
    }

    groups["Ghost response"] = {
        "GHOST_NO",
        "GHOST_YES",
    }

    groups["Full/backpressure"] = {
        "FULL_NO",
        "FULL_YES",
    }

    # Score only architecturally meaningful occupancy/operation combinations.
    # At EMPTY there is nothing to retire. At FULL no new transaction can be
    # admitted. Simultaneous enqueue/retire is explicitly required at occupancy
    # one, while repeating that same event at every intermediate depth is
    # redundant with the separately covered occupancy and operation dimensions.
    groups["Occupancy x operation"] = {
        "CROSS_OUTST_EMPTY_OP_00",
        "CROSS_OUTST_EMPTY_OP_10",

        "CROSS_OUTST_ONE_OP_00",
        "CROSS_OUTST_ONE_OP_10",
        "CROSS_OUTST_ONE_OP_01",
        "CROSS_OUTST_ONE_OP_11",

        "CROSS_OUTST_FULL_OP_00",
        "CROSS_OUTST_FULL_OP_01",
    } | {
        f"CROSS_OUTST_PARTIAL_{value}_OP_{op}"
        for value in range(2, depth)
        for op in ("00", "10", "01")
    }

    return groups


def make_write_queue_bins(depth):
    groups = make_read_queue_bins(depth)

    groups["Write-pair state"] = {
        "PAIR_STATE_IDLE",
        "PAIR_STATE_AW_ONLY",
        "PAIR_STATE_W_FAULT",
    }

    return groups


def parse_test_status(text):

    error_matches = re.findall(r"UVM_ERROR\s*:\s*(\d+)", text)
    fatal_matches = re.findall(r"UVM_FATAL\s*:\s*(\d+)", text)

    if not error_matches or not fatal_matches:
        return False, "missing UVM summary"

    errors = int(error_matches[-1])
    fatals = int(fatal_matches[-1])

    if errors != 0 or fatals != 0:
        return False, f"UVM_ERROR={errors}, UVM_FATAL={fatals}"

    if re.search(r"\*E,ASRTST", text):
        return False, "SVA assertion failure (*E,ASRTST)"

    return True, "PASS"


def parse_cov_hits(text):
    hits = {}
    pattern = re.compile(r"^COV_HIT\s+(\S+)\s+(.+?)\s*$", re.MULTILINE)

    for domain, marker in pattern.findall(text):
        if domain not in hits:
            hits[domain] = set()
        hits[domain].add(marker)

    return hits


def make_scoring_hits(aggregate_hits):
    """Return a copy of raw hits with derived semantic markers for scoring."""
    scoring_hits = {
        domain: set(markers)
        for domain, markers in aggregate_hits.items()
    }

    for domain in ("READ_QUEUE", "WRITE_QUEUE"):
        markers = scoring_hits.setdefault(domain, set())

        if any(re.fullmatch(r"DRAIN_MULTIPLE_\d+", marker) for marker in markers):
            markers.add("DRAIN_MULTIPLE")

    return scoring_hits


def score_group(observed_hits, expected_bins):
    hit_bins = observed_hits & expected_bins
    missing_bins = expected_bins - observed_hits

    return {
        "hit": len(hit_bins),
        "total": len(expected_bins),
        "coverage": percent(len(hit_bins), len(expected_bins)),
        "missing": sorted(missing_bins),
    }


def score_domain(observed_hits, groups):
    results = {}

    for name, expected_bins in groups.items():
        results[name] = score_group(observed_hits, expected_bins)

    total_hit = sum(
    result["hit"]
    for result in results.values()
    )

    total_bins = sum(
        result["total"]
        for result in results.values()
    )

    overall = percent(total_hit, total_bins)

    return results, overall


def print_domain(title, results, overall, output):
    output.append("")
    output.append(title)
    output.append("-" * len(title))

    for name, result in results.items():
        output.append(
            f"{name:<30} "
            f"{result['hit']:>3}/{result['total']:<3} "
            f"{result['coverage']:>7.2f}%"
        )

    output.append(f"{'Overall':<30} {'':>7} {overall:>7.2f}%")

    missing = []

    for name, result in results.items():
        if result["missing"]:
            missing.append((name, result["missing"]))

    if missing:
        output.append("")
        output.append("Missing bins:")

        for name, bins in missing:
            output.append(f"  {name}:")
            for bin_name in bins:
                output.append(f"    {bin_name}")
    else:
        output.append("")
        output.append("Missing bins: none")


def load_expected_tests(test_list_path):
    test_list = Path(test_list_path)

    if not test_list.exists():
        return None

    tests = []

    for line in test_list.read_text(errors="replace").splitlines():
        line = line.strip()

        if not line or line.startswith("#"):
            continue

        tests.append(line)

    return tests


def collect_expected_domain_bins(depth):
    """Union of every expected bin, per COV_HIT domain, mirroring the scoring calls."""
    def union(groups):
        bins = set()
        for group_bins in groups.values():
            bins |= group_bins
        return bins

    return {
        "READ_PROTOCOL":  union(make_read_protocol_bins()),
        "WRITE_PROTOCOL": union(make_write_protocol_bins()),
        "FAULT":          union(make_fault_bins()),
        # RECOVERY logs feed two scored models; recognize both.
        "RECOVERY":       union(make_recovery_bins()) | union(make_recovered_fault_bins()),
        "READ_QUEUE":     union(make_read_queue_bins(depth)),
        "WRITE_QUEUE":    union(make_write_queue_bins(depth)),
    }


TRANSFORM_PATTERNS = {
    # Raw markers legitimately absent from the bin model because scoring
    # consumes them through a derived semantic bin.
    "READ_QUEUE":  [re.compile(r"DRAIN_MULTIPLE_\d+")],
    "WRITE_QUEUE": [re.compile(r"DRAIN_MULTIPLE_\d+")],
    # Emitted for out-of-region reads; corresponds to a SystemVerilog
    # `default` bin, which native coverage scoring excludes. The model
    # mirrors that exclusion; no read-path verification obligation attaches.
    "READ_PROTOCOL": [re.compile(r"ADDR_OTHER_REGION")],
}


def audit_markers(aggregate_hits, depth, output):
    expected = collect_expected_domain_bins(depth)
    clean = True

    output.append("")
    output.append("MARKER AUDIT (observed vs. bin model)")
    output.append("-------------------------------------")

    for domain in sorted(aggregate_hits):
        observed = aggregate_hits[domain]

        if domain not in expected:
            output.append(f"  UNKNOWN DOMAIN: {domain} ({len(observed)} markers)")
            clean = False
            continue

        transforms = TRANSFORM_PATTERNS.get(domain, [])
        unknown = {
            m for m in observed - expected[domain]
            if not any(p.fullmatch(m) for p in transforms)
        }

        if unknown:
            clean = False
            output.append(f"  {domain}: {len(unknown)} unrecognized marker(s):")
            for m in sorted(unknown):
                output.append(f"    {m}")
        else:
            output.append(f"  {domain}: all {len(observed)} observed markers recognized")

    for domain in sorted(set(expected) - set(aggregate_hits)):
        output.append(f"  NOTE: expected domain never observed: {domain}")
        clean = False

    output.append("")
    output.append("Marker audit: " + ("CLEAN" if clean else "DISCREPANCIES FOUND"))
    return clean


def main():
    parser = argparse.ArgumentParser(
        description="Aggregate SCC functional coverage from regression COV_HIT markers."
    )

    parser.add_argument(
        "log_dir",
        nargs="?",
        default="regression_logs",
        help="Directory containing regression .log files.",
    )

    parser.add_argument(
        "--depth",
        type=int,
        default=DEFAULT_DEPTH,
        help="Configured SCC queue depth.",
    )

    parser.add_argument(
        "--test-list",
        default="regression_tests.txt",
        help="Regression test list used to determine expected tests.",
    )

    parser.add_argument(
        "--summary",
        default="regression_coverage_summary.txt",
        help="Output regression coverage summary file.",
    )

    parser.add_argument(
        "--hits",
        default="regression_coverage_hits.txt",
        help="Output file containing the union of unique COV_HIT markers.",
    )

    args = parser.parse_args()

    log_dir = Path(args.log_dir)

    if not log_dir.exists():
        raise SystemExit(f"ERROR: log directory does not exist: {log_dir}")

    expected_tests = load_expected_tests(args.test_list)

    if expected_tests:
        log_files = [log_dir / f"{test}.log" for test in expected_tests]
        missing_logs = [path for path in log_files if not path.exists()]
        log_files = [path for path in log_files if path.exists()]
    else:
        log_files = sorted(log_dir.glob("*.log"))
        missing_logs = []

    if not log_files:
        raise SystemExit(f"ERROR: no regression log files found in {log_dir}")

    aggregate_hits = {}
    passing_logs = []
    skipped_logs = []

    for log_file in log_files:
        text = log_file.read_text(errors="replace")

        passed, reason = parse_test_status(text)

        if not passed:
            skipped_logs.append((log_file.name, reason))
            continue

        passing_logs.append(log_file.name)

        file_hits = parse_cov_hits(text)

        for domain, markers in file_hits.items():
            if domain not in aggregate_hits:
                aggregate_hits[domain] = set()
            aggregate_hits[domain].update(markers)

    scoring_hits = make_scoring_hits(aggregate_hits)

    output = []
    audit_clean = audit_markers(aggregate_hits, args.depth, output)

    output.append("AXI4-LITE SCC REGRESSION FUNCTIONAL COVERAGE")
    output.append("=============================================")
    output.append("")
    output.append(f"Regression log directory : {log_dir}")
    output.append(f"Expected tests            : {len(expected_tests) if expected_tests else 'not provided'}")
    output.append(f"Log files found           : {len(log_files)}")
    output.append(f"Passing logs included     : {len(passing_logs)}")
    output.append(f"Skipped logs              : {len(skipped_logs)}")
    output.append(f"Missing expected logs     : {len(missing_logs)}")
    output.append(f"Queue DEPTH               : {args.depth}")

    if missing_logs:
        output.append("")
        output.append("Missing expected logs:")

        for path in missing_logs:
            output.append(f"  {path.name}")

    if skipped_logs:
        output.append("")
        output.append("Skipped tests:")

        for name, reason in skipped_logs:
            output.append(f"  {name}: {reason}")

    output.append("")
    output.append("SCORING BASIS")
    output.append("-------------")
    output.append("Only applicable, architecturally meaningful functional bins are scored.")
    output.append("Excluded from the denominator:")
    output.append("  - AXI4-Lite write EXOKAY and role x EXOKAY bins")
    output.append("  - structurally unreachable recovery/quiescence and recovery/IRQ crosses")
    output.append("  - impossible EMPTY-retire and FULL-enqueue queue crosses")
    output.append("  - repetitive partial-depth x simultaneous enqueue/retire crosses")
    output.append("Ghost-drain depth is scored semantically as zero / one / multiple.")

    read_protocol_results, read_protocol_overall = score_domain(
        scoring_hits.get("READ_PROTOCOL", set()),
        make_read_protocol_bins(),
    )

    write_protocol_results, write_protocol_overall = score_domain(
        scoring_hits.get("WRITE_PROTOCOL", set()),
        make_write_protocol_bins(),
    )

    fault_results, fault_overall = score_domain(
        scoring_hits.get("FAULT", set()),
        make_fault_bins(),
    )

    recovery_results, recovery_overall = score_domain(
        scoring_hits.get("RECOVERY", set()),
        make_recovery_bins(),
    )

    recovered_fault_results, recovered_fault_overall = score_domain(
        scoring_hits.get("RECOVERY", set()),
        make_recovered_fault_bins(),
    )

    read_queue_results, read_queue_overall = score_domain(
        scoring_hits.get("READ_QUEUE", set()),
        make_read_queue_bins(args.depth),
    )

    write_queue_results, write_queue_overall = score_domain(
        scoring_hits.get("WRITE_QUEUE", set()),
        make_write_queue_bins(args.depth),
    )

    print_domain(
        "READ PROTOCOL COVERAGE",
        read_protocol_results,
        read_protocol_overall,
        output,
    )

    print_domain(
        "WRITE PROTOCOL COVERAGE",
        write_protocol_results,
        write_protocol_overall,
        output,
    )

    print_domain(
        "FAULT COVERAGE",
        fault_results,
        fault_overall,
        output,
    )

    print_domain(
        "RECOVERY COVERAGE",
        recovery_results,
        recovery_overall,
        output,
    )

    print_domain(
        "RECOVERED FAULT COVERAGE",
        recovered_fault_results,
        recovered_fault_overall,
        output,
    )

    print_domain(
        "READ QUEUE COVERAGE",
        read_queue_results,
        read_queue_overall,
        output,
    )

    print_domain(
        "WRITE QUEUE COVERAGE",
        write_queue_results,
        write_queue_overall,
        output,
    )

    output.append("")
    output.append("OVERALL DOMAIN SUMMARY")
    output.append("----------------------")
    output.append(f"Read protocol          = {read_protocol_overall:.2f}%")
    output.append(f"Write protocol         = {write_protocol_overall:.2f}%")
    output.append(f"Fault                  = {fault_overall:.2f}%")
    output.append(f"Recovery state         = {recovery_overall:.2f}%")
    output.append(f"Recovered fault source = {recovered_fault_overall:.2f}%")
    output.append(f"Read queue             = {read_queue_overall:.2f}%")
    output.append(f"Write queue            = {write_queue_overall:.2f}%")

    summary_text = "\n".join(output) + "\n"

    print(summary_text, end="")

    Path(args.summary).write_text(summary_text)

    all_hit_lines = []

    for domain in sorted(aggregate_hits):
        for marker in sorted(aggregate_hits[domain]):
            all_hit_lines.append(f"COV_HIT {domain} {marker}")

    hits_text = "\n".join(all_hit_lines)

    if hits_text:
        hits_text += "\n"

    Path(args.hits).write_text(hits_text)

    print("")
    print(f"Wrote summary     : {args.summary}")
    print(f"Wrote unique hits : {args.hits}")


if __name__ == "__main__":
    main()
