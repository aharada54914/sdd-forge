"""Owner-controlled AWS pins and T-012 authenticated durable intent fence.

This is trusted executor configuration, never deployment input. No new state store.
"""

from __future__ import annotations
from dataclasses import dataclass
import re
from cloud import c, digest
from cloud_authorization import GitHubAdmission, _policy_valid, decode as auth_decode


@dataclass(frozen=True)
class Control:
    execution_role_arn: str
    bucket: str
    unit_id: str
    existing_stack_id: str | None

    def validate(self, policy, request: dict) -> None:
        c._require(request["unit_id"] == self.unit_id, "UNIT_AUTHORITY_MISMATCH")
        c._require(
            re.fullmatch(
                r"arn:aws:iam::" + policy.account_id + r":role/[A-Za-z0-9_+=,.@/-]+",
                self.execution_role_arn,
            )
            and self.execution_role_arn != policy.aws_role_arn,
            "EXECUTION_ROLE_PIN_REQUIRED",
        )
        c._require(
            self.bucket
            == "cdk-hnb659fds-assets-" + policy.account_id + "-" + policy.region,
            "ASSET_DESTINATION_PIN",
        )
        if self.existing_stack_id is not None:
            c._require(
                re.fullmatch(
                    r"arn:aws:cloudformation:"
                    + re.escape(policy.region)
                    + ":"
                    + policy.account_id
                    + ":stack/"
                    + re.escape(policy.deployment_scope)
                    + r"/[A-Za-z0-9-]+",
                    self.existing_stack_id,
                ),
                "STACK_OWNER_PIN_REQUIRED",
            )


def intent_history(
    self, preview_ref: dict | None, *, read_only: bool = False, prepare: bool = False
) -> dict:
    """Bounded authenticated repository history, never an artifact absence claim.

    shortcut: require the entire dispatch history in one 100-run page; larger
    control repositories fail closed until a reviewed durable-history upgrade.
    Retention/deletion/visibility and exclusive writer prerequisites are external.
    """
    p = self.boundary.policy
    _policy_valid(p)
    c._require(p.operation in ("prepare", "apply"), "STAGE_MISMATCH")
    preview_sha = preview_ref["sha256"] if preview_ref else "none"
    github = GitHubAdmission(p, self.boundary.runtime, self.boundary.transport)
    _, claims = github.oidc(int(self.boundary.clock()))
    if not read_only:
        github.metadata(claims, self.request_ref["sha256"], preview_sha)
    url = (
        f"https://api.github.com/repos/{p.repository}/actions/runs"
        "?event=workflow_dispatch&per_page=100&page=1"
    )
    raw = self.boundary.transport.request(
        "GET",
        url,
        {
            "Authorization": "Bearer " + self.boundary.runtime.github_token,
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    history = auth_decode(raw)
    total, runs = history["total_count"], history["workflow_runs"]
    c._require(
        type(total) is int
        and 1 <= total <= 100
        and type(runs) is list
        and len(runs) == total,
        "INTENT_HISTORY_INCOMPLETE",
    )
    ids, records, prior = set(), [], []
    current_id = int(claims["run_id"])
    for run in runs:
        c._require(
            type(run["id"]) is int
            and run["id"] > 0
            and run["id"] not in ids
            and run["event"] == "workflow_dispatch",
            "INTENT_HISTORY_INVALID",
        )
        ids.add(run["id"])
        for key in ("repository", "head_repository"):
            c._require(
                type(run[key]["id"]) is int
                and run[key]["id"] == p.repository_id
                and run[key]["full_name"] == p.repository,
                "INTENT_HISTORY_REPOSITORY",
            )
        path, title = run["path"], run["display_title"]
        c._require(
            type(path) is str
            and type(title) is str
            and type(run["head_sha"]) is str
            and re.fullmatch(r"[a-f0-9]{40}", run["head_sha"])
            and type(run["run_attempt"]) is int
            and run["run_attempt"] >= 1,
            "INTENT_HISTORY_INVALID",
        )
        match = re.fullmatch(r"cloud:([a-f0-9]{64}):(none|[a-f0-9]{64})", title)
        # Renamed/older workflows cannot erase a matching intent. Ambiguous
        # titles from the governed workflow cannot prove absence either.
        c._require(
            match or (path != p.workflow and not title.startswith("cloud:")),
            "INTENT_HISTORY_TITLE",
        )
        if run["id"] == current_id:
            c._require(
                path == p.workflow
                and run["head_sha"] == p.workflow_revision
                and run["run_attempt"] == 1
                and run["status"] == "in_progress"
                and run["conclusion"] is None
                and title == f"cloud:{self.request_ref['sha256']}:{preview_sha}",
                "INTENT_HISTORY_CURRENT",
            )
        elif (
            match
            and match[1] == self.request_ref["sha256"]
            and (prepare or match[2] != "none")
        ):
            # Even canceled/unapproved/reconcile dispatches conservatively fence;
            # no outcome or new preview/approval can establish safe resubmission.
            prior.append(run["id"])
        records.append(
            {
                k: run[k]
                for k in ("id", "path", "head_sha", "display_title", "run_attempt")
            }
        )
    c._require(current_id in ids, "INTENT_HISTORY_CURRENT_MISSING")
    return dict(
        repository=p.repository,
        repository_id=p.repository_id,
        current_run_id=current_id,
        prior_run_ids=sorted(prior),
        history=dict(
            url=url, total_count=total, response_sha256=digest(raw), runs=records
        ),
    )
