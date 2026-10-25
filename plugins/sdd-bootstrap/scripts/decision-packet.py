#!/usr/bin/env python3
"""Validate and display a passive decision packet against its current pinned inputs."""

import argparse
import hashlib
import html
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[3]


def module(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


inputs = module(
    "decision_inputs", "plugins/sdd-quality-loop/scripts/review-conditional-inputs.py"
)
OUTCOMES = {"success", "failure", "timeout", "cancelled", "not-run", "unknown"}


def text(value):
    if not isinstance(value, str) or not value.strip():
        raise ValueError("nonempty text required")
    return value


def strings(value):
    if not isinstance(value, list):
        raise ValueError("list required")
    for item in value:
        text(item)


def pin(root, reference):
    if not isinstance(reference, dict) or set(reference) != {"path", "sha256"}:
        raise ValueError("invalid reference")
    path = reference["path"]
    if (
        not isinstance(path, str)
        or path.startswith("/")
        or ":" in path
        or not isinstance(reference["sha256"], str)
        or not re.fullmatch("[0-9a-f]{64}", reference["sha256"])
    ):
        raise ValueError("unsafe reference")
    raw = inputs.read_safe(root, path)
    if hashlib.sha256(raw).hexdigest() != reference["sha256"]:
        raise ValueError("stale reference: " + path)
    return raw


def measured(root, observation, packet, alternative):
    source = observation["measurement"]
    if not isinstance(source, dict) or set(source) != {
        "directory",
        "span_id",
        "run_id",
        "records",
    }:
        raise ValueError("executed outcome requires a measurement source")
    directory = source["directory"]
    if (
        not isinstance(directory, str)
        or ":" in directory
        or "\\" in directory
        or any(p in ("", ".", "..") for p in directory.split("/"))
    ):
        raise ValueError("unsafe measurement directory")
    if not isinstance(source["records"], list) or not source["records"]:
        raise ValueError("measurement record inventory required")
    paths = set()
    snapshots = {}
    for record in source["records"]:
        raw = pin(root, record)
        if not record["path"].startswith(directory + "/") or record["path"] in paths:
            raise ValueError("invalid measurement inventory")
        paths.add(record["path"])
        snapshots[record["path"][len(directory) + 1 :]] = raw
        stored = json.loads(raw, object_pairs_hook=inputs.unique_object)
        if not isinstance(stored, dict):
            raise ValueError("invalid measurement record")
        for name in ("inputs", "logs", "artifacts"):
            for ref in stored.get(name, []):
                original = Path(ref["path"])
                relative = (
                    original.relative_to(root).as_posix()
                    if original.is_absolute()
                    else original.as_posix()
                )
                pin(root, {"path": relative, "sha256": ref["sha256"]})
    current = {
        p.relative_to(root).as_posix() for p in (root / directory).rglob("*.json")
    }
    if paths != current:
        raise ValueError("measurement inventory changed")
    measurement = module(
        "decision_measurement", "plugins/sdd-quality-loop/scripts/run_measurement.py"
    )
    try:
        # Reduce exactly the admitted bytes, not a second mutable source read.
        with tempfile.TemporaryDirectory(prefix="decision-measurement-") as temporary:
            snapshot = Path(temporary)
            for relative, raw in snapshots.items():
                target = snapshot / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            summary = measurement.summarize(snapshot, as_of=None, ref_root=root)
    except measurement.MeasurementError as exc:
        raise ValueError("invalid measurement") from exc
    header = summary["measurement"]
    if not summary["complete"] or (
        header["feature"],
        header["task"],
        header["run_id"],
    ) != (packet["feature"], packet["task"], source["run_id"]):
        raise ValueError("incomplete or differently scoped measurement")
    if (
        header["variant_ref"] != alternative["id"]
        or header["parent_run_id"] != packet["run_id"]
    ):
        raise ValueError("measurement belongs to another alternative or parent run")
    spans = [s for s in summary["spans"] if s["span_id"] == source["span_id"]]
    if len(spans) != 1:
        raise ValueError("measurement span missing")
    selected = packet["inputs"] + [
        packet["approval"],
        alternative["preview"],
        alternative["diff"],
    ]
    observed = {
        (
            str(
                Path(ref["path"])
                if Path(ref["path"]).is_absolute()
                else root / ref["path"]
            ),
            ref["sha256"],
        )
        for ref in spans[0]["inputs"]
    }
    if not {(str(root / ref["path"]), ref["sha256"]) for ref in selected} <= observed:
        raise ValueError("measurement does not bind the selected alternative inputs")
    actual = {"interrupted": "cancelled"}.get(spans[0]["outcome"], spans[0]["outcome"])
    if actual != observation["outcome"]:
        raise ValueError("reported outcome contradicts measured outcome")
    evidence = observation["evidence"]
    if not any(
        (Path(log["path"]) if Path(log["path"]).is_absolute() else root / log["path"])
        == root / evidence["path"]
        and log["sha256"] == evidence["sha256"]
        for log in spans[0]["logs"]
    ):
        raise ValueError("displayed evidence is not a measured span log")


def packet_digest(packet):
    return hashlib.sha256(
        json.dumps(
            packet,
            sort_keys=True,
            ensure_ascii=False,
            separators=(",", ":"),
            allow_nan=False,
        ).encode("utf-8")
    ).hexdigest()


def signed_choice(root, relative, expected=None):
    auth = module(
        "decision_choice_auth",
        "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py",
    )
    live_paths = (
        relative,
        relative.removesuffix(".json") + ".approval.json",
        relative.removesuffix(".json") + ".approved.json",
        "sdd/approver-registry.yaml",
    )
    try:
        auth._check_no_publish_in_progress(*live_paths, root=root)
    except auth.ValidateApprovalSidecarError as exc:
        raise ValueError("human choice publication in progress") from exc
    raw = inputs.read_safe(root, relative)
    if expected is not None and hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError("choice changed since selection")
    record = json.loads(raw, object_pairs_hook=inputs.unique_object)
    if not isinstance(record, dict):
        raise ValueError("invalid choice")
    feature, identifier = record.get("feature"), record.get("decision_id")
    if (
        not isinstance(feature, str)
        or not re.fullmatch("[a-z0-9][a-z0-9-]*", feature)
        or not isinstance(identifier, str)
        or not re.fullmatch("[a-zA-Z0-9][a-zA-Z0-9-]{0,63}", identifier)
    ):
        raise ValueError("invalid choice identity")
    prefix = "specs/" + feature + "/decisions/" + identifier + "/decision-choice"
    if relative != prefix + ".json":
        raise ValueError("choice file identity mismatch")
    approval_raw = inputs.read_safe(root, prefix + ".approval.json")
    approval = json.loads(approval_raw, object_pairs_hook=inputs.unique_object)
    if (
        not isinstance(approval, dict)
        or approval.get("schema") != "sdd-decision-choice-approval/v1"
    ):
        raise ValueError("choice signature type required")
    registry_raw = inputs.read_safe(root, "sdd/approver-registry.yaml")
    with tempfile.TemporaryDirectory(prefix="decision-choice-") as temporary:
        directory = Path(temporary)
        content_path, approval_path, registry_path = (
            directory / x for x in ("choice.json", "approval.json", "registry.yaml")
        )
        content_path.write_bytes(raw)
        approval_path.write_bytes(approval_raw)
        registry_path.write_bytes(registry_raw)
        try:
            auth.run_standard_validation(content_path, approval_path, registry_path)
        except auth.ValidateApprovalSidecarError as exc:
            raise ValueError("invalid existing choice approval") from exc
    try:
        auth._check_no_publish_in_progress(*live_paths, root=root)
    except auth.ValidateApprovalSidecarError as exc:
        raise ValueError("human choice publication in progress") from exc
    if (
        inputs.read_safe(root, relative),
        inputs.read_safe(root, prefix + ".approval.json"),
        inputs.read_safe(root, "sdd/approver-registry.yaml"),
    ) != (raw, approval_raw, registry_raw):
        raise ValueError("human choice changed during validation")
    return record, approval["primary_approval"]["approver"], raw, approval_raw


def choice_heads(root, feature, task):
    directory = root / "specs" / feature / "decisions"
    signed_paths = sorted(directory.glob("*/decision-choice.approval.json"))
    paths = [p.with_name("decision-choice.json") for p in signed_paths]
    if len(paths) > 128:
        raise ValueError("choice directory exceeds bounded validation")
    records = {}
    for path in paths:
        sidecar = path.with_name("decision-choice.approval.json")
        if not sidecar.exists() and not sidecar.is_symlink():
            continue
        relative = path.relative_to(root).as_posix()
        record, _, raw, approval = signed_choice(root, relative)
        if (record["feature"], record["task"]) == (feature, task):
            records[relative] = (
                record,
                hashlib.sha256(raw).hexdigest(),
                hashlib.sha256(approval).hexdigest(),
            )
    referenced = set()
    for record, _, _ in records.values():
        previous = record["previous"]
        if previous is None:
            continue
        path = previous["record"]["path"]
        if (
            path not in records
            or previous["record"]["sha256"] != records[path][1]
            or previous["approval"]
            != {
                "path": path.removesuffix(".json") + ".approval.json",
                "sha256": records[path][2],
            }
        ):
            raise ValueError("signed choice history is missing or changed")
        referenced.add(path)
    heads = {path: value for path, value in records.items() if path not in referenced}
    if records and len(heads) != 1:
        raise ValueError(
            "signed choice history has conflicting or cyclic current records"
        )
    if sorted(directory.glob("*/decision-choice.approval.json")) != signed_paths:
        raise ValueError("signed choice roster changed during validation")
    return heads


def choice_history(root, selected, feature, task):
    history, seen = [], set()
    record = selected
    while record["previous"] is not None:
        if len(history) >= 32:
            raise ValueError("choice history exceeds bounded validation")
        previous = record["previous"]
        pin(root, previous["record"])
        approval_bytes = pin(root, previous["approval"])
        path = previous["record"]["path"]
        if path in seen:
            raise ValueError("cyclic choice history")
        seen.add(path)
        old, approver, _, checked_approval = signed_choice(
            root, path, previous["record"]["sha256"]
        )
        if (
            checked_approval != approval_bytes
            or previous["approval"]["path"]
            != path.removesuffix(".json") + ".approval.json"
        ):
            raise ValueError("history signature reference mismatch")
        if (old["feature"], old["task"]) != (feature, task):
            raise ValueError("choice history target mismatch")
        history.append({"choice": old, "approver": approver})
        record = old
    return history


def attach_choice(root, result, choice_id, expected_sha256):
    if not isinstance(choice_id, str) or not re.fullmatch(
        "[a-zA-Z0-9][a-zA-Z0-9-]{0,63}", choice_id
    ):
        raise ValueError("invalid decision id")
    if not isinstance(expected_sha256, str) or not re.fullmatch(
        "[0-9a-f]{64}", expected_sha256
    ):
        raise ValueError("caller-pinned choice digest required")
    packet = result["packet"]
    relative = (
        "specs/"
        + packet["feature"]
        + "/decisions/"
        + choice_id
        + "/decision-choice.json"
    )
    record, approver, _, _ = signed_choice(root, relative, expected_sha256)
    if (
        record["feature"],
        record["task"],
        record["run_id"],
        record["packet_sha256"],
    ) != (packet["feature"], packet["task"], packet["run_id"], packet_digest(packet)):
        raise ValueError("choice is stale or belongs to another packet")
    if record["alternative"] not in {a["id"] for a in packet["alternatives"]}:
        raise ValueError("choice selects an unknown alternative")
    if (
        packet["concept_test"]
        and record["choice"] == "adopt"
        and result["concept_decision"] not in ("proceed", "not-required")
    ):
        raise ValueError("concept decision prevents adoption")
    expiry = datetime.fromisoformat(record["valid_until"].replace("Z", "+00:00"))
    if expiry.tzinfo is None or expiry <= datetime.now(timezone.utc):
        raise ValueError("choice expired")
    history = choice_history(root, record, packet["feature"], packet["task"])
    heads = choice_heads(root, packet["feature"], packet["task"])
    if relative not in heads or heads[relative][1] != expected_sha256:
        raise ValueError("choice has a signed successor; select the current record")
    return dict(
        result,
        human_decision=record["choice"],
        choice=record,
        choice_approver=approver,
        choice_history=history,
    )


def validate(root, packet, feature, task, run_id, expected_sha256):
    if not isinstance(expected_sha256, str) or packet_digest(packet) != expected_sha256:
        raise ValueError("packet changed since selection")
    required = {
        "schema",
        "feature",
        "task",
        "run_id",
        "objective",
        "scenario",
        "hypotheses",
        "inputs",
        "approval",
        "alternatives",
        "recommendation",
        "unknowns",
        "risks",
        "next_action",
        "previous",
        "concept_test",
    }
    if (
        not isinstance(packet, dict)
        or set(packet) != required
        or packet["schema"] != "decision-packet/v1"
    ):
        raise ValueError("invalid decision-packet/v1")
    if (packet["feature"], packet["task"], packet["run_id"]) != (feature, task, run_id):
        raise ValueError("packet belongs to a different feature/task/run")
    if not re.fullmatch("[a-z0-9][a-z0-9-]*", feature) or not re.fullmatch(
        "T-[0-9]+", task
    ):
        raise ValueError("invalid target")
    for key in ("objective", "scenario", "next_action", "run_id"):
        text(packet[key])
    for key in ("hypotheses", "unknowns", "risks"):
        strings(packet[key])
    if (
        not packet["hypotheses"]
        or not isinstance(packet["inputs"], list)
        or not packet["inputs"]
    ):
        raise ValueError("hypotheses and pinned inputs required")
    refs = packet["inputs"] + [packet["approval"]]
    for ref in refs:
        pin(root, ref)
    if len({r["path"] for r in refs}) != len(refs):
        raise ValueError("duplicate input reference")
    if packet["approval"]["path"] != "specs/" + feature + "/tasks.md":
        raise ValueError("current task authority must be referenced")
    alternatives = packet["alternatives"]
    if not isinstance(alternatives, list) or not 1 <= len(alternatives) <= 3:
        raise ValueError("one to three alternatives required")
    ids = set()
    for alternative in alternatives:
        if not isinstance(alternative, dict) or set(alternative) != {
            "id",
            "description",
            "preview",
            "diff",
            "observations",
            "counterevidence",
            "unknowns",
        }:
            raise ValueError("invalid alternative")
        identifier = text(alternative["id"])
        if (
            not re.fullmatch("[a-zA-Z0-9][a-zA-Z0-9-]*", identifier)
            or identifier in ids
        ):
            raise ValueError("invalid or duplicate alternative id")
        ids.add(identifier)
        text(alternative["description"])
        strings(alternative["counterevidence"])
        strings(alternative["unknowns"])
        for key in ("preview", "diff"):
            pin(root, alternative[key])
        observations = alternative["observations"]
        if not isinstance(observations, list) or not observations:
            raise ValueError(
                "every alternative needs observations, including not-run/unknown"
            )
        for observation in observations:
            if (
                not isinstance(observation, dict)
                or set(observation) != {"outcome", "reason", "evidence", "measurement"}
                or observation["outcome"] not in OUTCOMES
            ):
                raise ValueError("invalid observation")
            text(observation["reason"])
            if observation["evidence"] is None:
                if observation["outcome"] not in ("unknown", "not-run"):
                    raise ValueError("executed observations require source evidence")
            else:
                pin(root, observation["evidence"])
            if observation["outcome"] not in ("unknown", "not-run"):
                measured(root, observation, packet, alternative)
            elif observation["measurement"] is not None:
                raise ValueError(
                    "unknown/not-run must not claim a completed measurement"
                )
    recommendation = packet["recommendation"]
    if not isinstance(recommendation, dict) or set(recommendation) != {
        "alternative",
        "reason",
    }:
        raise ValueError("invalid recommendation")
    if (
        recommendation["alternative"] is not None
        and recommendation["alternative"] not in ids
    ):
        raise ValueError("unknown recommended alternative")
    text(recommendation["reason"])
    previous = packet["previous"]
    history = None
    if previous is not None:
        # History is hash-pinned but not revalidated against today's changed inputs.
        # It cannot authorize continuation; it preserves earlier rejection/hold reasons.
        history = json.loads(
            pin(root, previous), object_pairs_hook=inputs.unique_object
        )
        if (
            not isinstance(history, dict)
            or history.get("schema") != "decision-packet/v1"
            or history.get("feature") != feature
            or history.get("task") != task
        ):
            raise ValueError("history belongs to another target")
        old_recommendation = history.get("recommendation")
        if not isinstance(old_recommendation, dict) or set(old_recommendation) != {
            "alternative",
            "reason",
        }:
            raise ValueError("invalid prior recommendation")
        text(old_recommendation["reason"])
    decision = "pending"
    if packet["concept_test"]:
        if packet["concept_test"] is not True:
            raise ValueError("concept_test must be boolean")
        concept = module(
            "decision_concept", "plugins/sdd-domain/scripts/validate-concept-test.py"
        )
        record, _ = concept.evidence(root, feature)
        decision = record.get("decision", "not-required")
    elif packet["concept_test"] is not False:
        raise ValueError("concept_test must be boolean")
    return {
        "packet": packet,
        "history": history,
        "human_decision": "pending",
        "concept_decision": decision,
        "authority": "signed choices are display-only; task approvals and Done are unchanged",
    }


def escaped(value):
    # Source text is untrusted display data, including Markdown links and HTML.
    return (
        html.escape(str(value))
        .replace("\\", "\\\\")
        .replace("[", "\\[")
        .replace("]", "\\]")
        .replace("`", "\\`")
        .replace("*", "\\*")
        .replace("_", "\\_")
        .replace("#", "\\#")
        .replace("\n", " ")
    )


def render(result):
    packet = result["packet"]
    lines = [
        "# Decision packet",
        "",
        "Display only. This packet grants no approval.",
        "",
        "Target: "
        + escaped(packet["feature"] + "/" + packet["task"] + " — " + packet["run_id"]),
        "Objective: " + escaped(packet["objective"]),
        "Scenario: " + escaped(packet["scenario"]),
        "",
        "## Intake hypotheses",
        *("- " + escaped(x) for x in packet["hypotheses"]),
    ]
    for alternative in packet["alternatives"]:
        lines += [
            "",
            "## Alternative " + escaped(alternative["id"]),
            escaped(alternative["description"]),
        ]
        for key in ("preview", "diff"):
            ref = alternative[key]
            lines.append(
                key + ": " + escaped(ref["path"]) + " (SHA-256 " + ref["sha256"] + ")"
            )
        for observation in alternative["observations"]:
            lines.append(
                "- Reported "
                + observation["outcome"]
                + ": "
                + escaped(observation["reason"])
            )
            if observation["evidence"]:
                lines.append(
                    "  Evidence: "
                    + escaped(observation["evidence"]["path"])
                    + " (SHA-256 "
                    + observation["evidence"]["sha256"]
                    + ")"
                )
        for key in ("counterevidence", "unknowns"):
            lines.append(
                key
                + ": "
                + ("; ".join(escaped(x) for x in alternative[key]) or "none reported")
            )
    lines += [
        "",
        "## Recommendation (not a human decision)",
        escaped(packet["recommendation"]["alternative"] or "none")
        + ": "
        + escaped(packet["recommendation"]["reason"]),
        "Human alternative decision: " + result["human_decision"],
        "Separate concept decision: " + result["concept_decision"],
        "",
        "## Unknowns and risks",
        *("- " + escaped(x) for x in packet["unknowns"] + packet["risks"]),
        "Next: " + escaped(packet["next_action"]),
    ]
    if result["history"]:
        lines += [
            "",
            "## Previous recommendation",
            escaped(result["history"]["recommendation"]["reason"]),
            "Previous packet: " + escaped(packet["previous"]["path"]),
        ]
    if result.get("choice"):
        chosen = result["choice"]
        lines += [
            "",
            "## Signed human choice",
            escaped(chosen["choice"])
            + " "
            + escaped(chosen["alternative"])
            + ": "
            + escaped(chosen["reason"]),
            "Approver: " + escaped(result["choice_approver"]),
            "This choice grants no task approval or implementation permission.",
        ]
        for item in result["choice_history"]:
            old = item["choice"]
            lines += [
                "Previous "
                + escaped(old["choice"])
                + " "
                + escaped(old["alternative"])
                + ": "
                + escaped(old["reason"])
            ]
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--packet", required=True)
    parser.add_argument("--feature", required=True)
    parser.add_argument("--task", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument(
        "--packet-sha256",
        required=True,
        help="canonical JSON SHA-256 pinned by the caller when selecting this packet",
    )
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown")
    parser.add_argument(
        "--decision-id", help="existing signed immutable human choice to display"
    )
    parser.add_argument(
        "--choice-sha256", help="caller-pinned SHA-256 of selected choice bytes"
    )
    args = parser.parse_args(argv)
    try:
        root = args.root.resolve(strict=True)
        packet = json.loads(
            inputs.read_safe(root, args.packet), object_pairs_hook=inputs.unique_object
        )
        result = validate(
            root, packet, args.feature, args.task, args.run_id, args.packet_sha256
        )
        if bool(args.decision_id) != bool(args.choice_sha256):
            raise ValueError(
                "decision id and selected choice digest must be supplied together"
            )
        if args.decision_id:
            result = attach_choice(root, result, args.decision_id, args.choice_sha256)
        print(
            render(result)
            if args.format == "markdown"
            else json.dumps(result, ensure_ascii=False),
            end="\n",
        )
        return 0
    except (OSError, ValueError, TypeError, KeyError, AttributeError):
        print(
            json.dumps(
                {
                    "schema": "decision-packet-error/v1",
                    "error": "invalid-or-stale-packet",
                    "authority": "none",
                }
            )
        )
        return 2


if __name__ == "__main__":
    sys.exit(main())
