"""Read-only private EC2 observations. Native Query/REST protocols, no CLI shell.

Supported identity proof is a literal explicit-deny inline guard, NOT an IAM
simulator or an inference from attached role names. Other allows cannot widen
this guard's bound. SCPs, session policies and boundaries can only restrict it.
"""

from __future__ import annotations

import copy
from decimal import Decimal, InvalidOperation
import ipaddress
import re
from typing import Callable
import urllib.parse
import xml.etree.ElementTree as ET

from cloud import (
    c,
    decode as local_decode,
    read_bytes,
    output_path,
    publish_json,
    publish_bytes,
    safe_publication,
)
from aws_native import HttpsTransport, sign, xml
from cloud_verification import (
    decode,
    digest,
    native_time,
    metric_config,
    metric_start,
    samples,
    utc,
    publish_collection,
)

VERSIONS = {"ec2": "2016-11-15", "iam": "2010-05-08", "monitoring": "2010-08-01"}
NAMESPACES = {
    "ec2": "http://ec2.amazonaws.com/doc/2016-11-15/",
    "iam": "https://iam.amazonaws.com/doc/2010-05-08/",
    "monitoring": "http://monitoring.amazonaws.com/doc/2010-08-01/",
}
LISTS = {
    "reservationSet",
    "instancesSet",
    "groupSet",
    "networkInterfaceSet",
    "ipv6AddressesSet",
    "privateIpAddressesSet",
    "securityGroupInfo",
    "ipPermissions",
    "ipPermissionsEgress",
    "ipRanges",
    "ipv6Ranges",
    "groups",
    "prefixListIds",
    "Roles",
    "MetricAlarms",
    "CompositeAlarms",
    "Dimensions",
    "Datapoints",
}


def configuration(cfg: dict, *, resolved: bool = False) -> None:
    def identifier(v):
        c._match(v, r"[A-Za-z0-9_-]{1,128}")

    def arn(v):
        c._match(v, r"arn:aws:[a-z0-9-]+:(?:[a-z0-9-]+)?:[0-9]{12}:[A-Za-z0-9_./:-]+")

    def logical(v):
        c._match(v, r"[A-Za-z][A-Za-z0-9]{0,254}")

    fields = dict(
        vpc_id=lambda v: c._match(v, r"vpc-[a-f0-9]{8,17}"),
        subnet_id=lambda v: c._match(v, r"subnet-[a-f0-9]{8,17}"),
        instance_profile_arn=arn,
        role_arn=arn,
        guard_policy_name=identifier,
        workload_metric=metric_config,
    )
    backup_fields = dict(plan_id=identifier, vault_name=identifier, role_arn=arn)
    if resolved:
        fields.update(
            instance_id=lambda v: c._match(v, r"i-[a-f0-9]{17}"),
            security_group_ids=lambda v: c._list(
                v, lambda x: c._match(x, r"sg-[a-f0-9]{8,17}"), 1
            ),
            alarm_name=identifier,
        )
        backup_fields.update(selection_id=identifier)
    else:
        fields.update(
            instance_logical_id=logical,
            security_group_logical_ids=lambda v: c._list(v, logical, 1),
            alarm_logical_id=logical,
        )
        backup_fields.update(selection_logical_id=logical)
    c._record(cfg, fields, dict(backup=lambda v: c._record(v, backup_fields)))
    c._unique(cfg["security_group_ids" if resolved else "security_group_logical_ids"])
    c._require(
        not cfg["workload_metric"]["namespace"].startswith("AWS/"),
        "WORKLOAD_NAMESPACE_RESERVED",
    )


def guard_policy(namespace: str) -> dict:
    """Exact, deliberately narrow workload role: publish only one metric namespace.

    Presence of the unconditional Deny/NotAction is the privilege upper-bound
    proof even with other policies/resource grants. This collector never creates
    the policy or infers permission to publish from simulation. Received metrics
    are independently required. This does not claim all AWS operations are allowed.
    """
    return dict(
        Version="2012-10-17",
        Statement=[
            dict(Effect="Deny", NotAction="cloudwatch:PutMetricData", Resource="*"),
            dict(
                Effect="Deny",
                Action="cloudwatch:PutMetricData",
                Resource="*",
                Condition={"StringNotEquals": {"cloudwatch:namespace": namespace}},
            ),
            dict(
                Effect="Allow",
                Action="cloudwatch:PutMetricData",
                Resource="*",
                Condition={"StringEquals": {"cloudwatch:namespace": namespace}},
            ),
        ],
    )


def element(node: ET.Element):
    key = node.tag.split("}")[-1]
    if key in LISTS:
        c._require(
            all(n.tag.split("}")[-1] in ("item", "member") for n in node),
            "NATIVE_LIST_INVALID",
        )
        return [element(n) for n in node]
    if len(node):
        names = [n.tag.split("}")[-1] for n in node]
        c._unique(names)
        return {k: element(n) for k, n in zip(names, node)}
    return node.text or ""


def zero_threshold(value: object) -> bool:
    if not isinstance(value, str) or not re.fullmatch(
        r"[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?", value
    ):
        return False
    try:
        # Decimal preserves tiny nonzero values that binary floats underflow to zero.
        number = Decimal(value)
    except InvalidOperation:
        return False
    return number.is_finite() and number.is_zero()


class Collector:
    def __init__(
        self,
        scope: dict,
        cfg: dict,
        credentials: dict,
        *,
        principal: str,
        completed: str,
        age: int,
        clock: Callable[[], float],
        transport,
        run_id: str,
        unit_id: str,
    ):
        configuration(cfg, resolved=True)
        c._match(scope["account_id"], r"[0-9]{12}")
        c._match(scope["region"], r"[a-z]{2}-[a-z]+-[1-9]")
        account = scope["account_id"]
        for field, kind in [
            ("instance_profile_arn", "instance-profile"),
            ("role_arn", "role"),
        ]:
            c._match(
                cfg[field],
                r"arn:aws:iam::" + account + ":" + kind + r"/[A-Za-z0-9_/-]+",
            )
        if "backup" in cfg:
            c._match(
                cfg["backup"]["role_arn"],
                r"arn:aws:iam::" + account + r":role/[A-Za-z0-9_/-]+",
            )
        c._id(run_id)
        c._id(unit_id)
        c._text(principal)
        c._utc(completed)
        self.scope, self.cfg, self.credentials, self.principal = (
            scope,
            cfg,
            credentials,
            principal,
        )
        self.completed, self.age, self.clock, self.transport = (
            completed,
            age,
            clock,
            transport,
        )
        self.run_id, self.unit_id = run_id, unit_id
        self.trace: list[dict] = []
        self.directory = ""
        self.lease = int(clock()) + 120
        self.resource_arn = (
            f"arn:aws:ec2:{scope['region']}:{account}:instance/{cfg['instance_id']}"
        )

    def call(self, service: str, action: str, params: dict) -> dict:
        """Closed read operations; caller input can select no URL/action/query program."""
        allowed = {
            ("ec2", "DescribeInstances"): {"InstanceId.1"},
            ("ec2", "DescribeSecurityGroups"): {
                "GroupId." + str(i)
                for i in range(1, len(self.cfg["security_group_ids"]) + 1)
            },
            ("iam", "GetInstanceProfile"): {"InstanceProfileName"},
            ("iam", "GetRolePolicy"): {"RoleName", "PolicyName"},
            ("monitoring", "DescribeAlarms"): {"AlarmNames.member.1"},
            ("monitoring", "GetMetricStatistics"): {
                "Namespace",
                "MetricName",
                "StartTime",
                "EndTime",
                "Period",
                "Statistics.member.1",
                "Dimensions.member.1.Name",
                "Dimensions.member.1.Value",
            },
        }
        required = allowed.get((service, action))
        if (
            action == "GetMetricStatistics"
            and params.get("Namespace") == self.cfg["workload_metric"]["namespace"]
        ):
            assert required is not None
            required = required | {
                "Statistics.member.2",
                "Dimensions.member.2.Name",
                "Dimensions.member.2.Value",
                "Dimensions.member.3.Name",
                "Dimensions.member.3.Value",
            }
        c._require(
            required is not None and set(params) == required, "READ_OPERATION_DENIED"
        )
        region = "us-east-1" if service == "iam" else self.scope["region"]
        url = (
            "https://iam.amazonaws.com/"
            if service == "iam"
            else f"https://{service}.{region}.amazonaws.com/"
        )
        body = urllib.parse.urlencode(
            dict(Action=action, Version=VERSIONS[service], **params),
            quote_via=urllib.parse.quote,
        ).encode()
        raw = self.request(service, region, "POST", url, body)
        try:
            root = xml(raw, NAMESPACES[service])
        except ET.ParseError:
            raise c.ContractError("NATIVE_RESPONSE_INVALID") from None
        c._require(
            root.tag == "{" + NAMESPACES[service] + "}" + action + "Response",
            "NATIVE_RESPONSE_MISMATCH",
        )
        if service == "ec2":
            value = element(root)
        else:
            found = root.findall("{" + NAMESPACES[service] + "}" + action + "Result")
            c._require(len(found) == 1, "NATIVE_RESPONSE_MISMATCH")
            value = element(found[0])
        c._require(
            type(value) is dict
            and not any(value.get(k) for k in ("NextToken", "nextToken", "Marker"))
            and value.get("IsTruncated", "false") == "false",
            "PAGINATION_INCOMPLETE",
        )
        return value

    def request(
        self, service: str, region: str, method: str, url: str, body: bytes = b""
    ) -> bytes:
        c._require(int(self.clock()) < self.lease, "READ_CREDENTIAL_EXPIRED")
        headers = sign(
            method,
            url,
            body,
            {"content-type": "application/x-www-form-urlencoded"}
            if method == "POST"
            else {},
            self.credentials,
            service,
            region,
            int(self.clock()),
        )
        response = self.transport.request(
            method, url, headers, body if method == "POST" else None
        )
        c._require(int(self.clock()) < self.lease, "READ_CREDENTIAL_EXPIRED")
        c._require(
            type(response.body) is bytes and len(response.body) <= c.MAX_BYTES,
            "NATIVE_RESPONSE_INVALID",
        )
        self.trace.append(
            dict(
                locator=url,
                request_sha256=digest(body),
                response_sha256=digest(response.body),
                http_status=response.status,
            )
        )
        c._require(response.status == 200, "NATIVE_READ_UNAVAILABLE")
        return response.body

    def instance(self) -> dict:
        value = self.call(
            "ec2", "DescribeInstances", {"InstanceId.1": self.cfg["instance_id"]}
        )
        reservations = value["reservationSet"]
        c._require(len(reservations) == 1, "RESOURCE_ID_MISMATCH")
        reservation = reservations[0]
        c._require(
            reservation["ownerId"] == self.scope["account_id"], "RESOURCE_ID_MISMATCH"
        )
        machines = reservation["instancesSet"]
        c._require(len(machines) == 1, "RESOURCE_ID_MISMATCH")
        instance = machines[0]
        c._require(
            instance["instanceId"] == self.cfg["instance_id"], "RESOURCE_ID_MISMATCH"
        )
        return instance

    def resource(self) -> tuple[bool, str]:
        instance = self.instance()
        state = instance["instanceState"]["name"]
        c._enum(
            state,
            (
                "pending",
                "running",
                "shutting-down",
                "terminated",
                "stopping",
                "stopped",
            ),
        )
        return state == "running", utc(self.clock())

    def network(self) -> tuple[bool, str]:
        machine = self.instance()
        cfg = self.cfg
        c._require(
            machine["vpcId"] == cfg["vpc_id"]
            and machine["subnetId"] == cfg["subnet_id"],
            "NETWORK_ID_MISMATCH",
        )
        groups = {g["groupId"] for g in machine["groupSet"]}
        c._require(groups == set(cfg["security_group_ids"]), "NETWORK_ID_MISMATCH")
        if machine.get("ipAddress") or machine.get("ipv6Address"):
            return False, utc(self.clock())
        interfaces = machine["networkInterfaceSet"]
        c._require(len(interfaces) == 1, "NETWORK_CONTEXT_UNSUPPORTED")
        for nic in interfaces:
            c._require(
                nic["subnetId"] == cfg["subnet_id"]
                and {g["groupId"] for g in nic["groupSet"]} == groups,
                "NETWORK_ID_MISMATCH",
            )
            if (
                nic.get("association")
                or nic.get("ipv6AddressesSet")
                or any(
                    x.get("association") for x in nic.get("privateIpAddressesSet", [])
                )
            ):
                return False, utc(self.clock())
        security = self.call(
            "ec2",
            "DescribeSecurityGroups",
            {
                "GroupId." + str(i): v
                for i, v in enumerate(cfg["security_group_ids"], 1)
            },
        )["securityGroupInfo"]
        c._require(
            {g["groupId"] for g in security} == groups and len(security) == len(groups),
            "NETWORK_ID_MISMATCH",
        )
        for group in security:
            c._require(
                group["ownerId"] == self.scope["account_id"]
                and group["vpcId"] == cfg["vpc_id"],
                "NETWORK_ID_MISMATCH",
            )
            if group["ipPermissions"]:
                return False, utc(self.clock())
            for rule in group["ipPermissionsEgress"]:
                if (
                    rule["ipProtocol"] != "tcp"
                    or rule["fromPort"] != "443"
                    or rule["toPort"] != "443"
                ):
                    return False, utc(self.clock())
                c._require(
                    not any(
                        rule.get(k) for k in ("groups", "ipv6Ranges", "prefixListIds")
                    ),
                    "NETWORK_CONTEXT_UNSUPPORTED",
                )
                for cidr in rule["ipRanges"]:
                    network = ipaddress.ip_network(cidr["cidrIp"])
                    if not isinstance(
                        network, ipaddress.IPv4Network
                    ) or not network.subnet_of(ipaddress.IPv4Network("10.0.0.0/16")):
                        return False, utc(self.clock())
        return True, utc(self.clock())

    def identity(self) -> tuple[bool, str]:
        machine = self.instance()
        cfg = self.cfg
        c._require(
            machine["iamInstanceProfile"]["arn"] == cfg["instance_profile_arn"],
            "IDENTITY_MISMATCH",
        )
        value = self.call(
            "iam",
            "GetInstanceProfile",
            dict(InstanceProfileName=cfg["instance_profile_arn"].rsplit("/", 1)[1]),
        )["InstanceProfile"]
        c._require(
            value["Arn"] == cfg["instance_profile_arn"]
            and len(value["Roles"]) == 1
            and value["Roles"][0]["Arn"] == cfg["role_arn"],
            "IDENTITY_MISMATCH",
        )
        role = value["Roles"][0]["RoleName"]
        c._require(role == cfg["role_arn"].rsplit("/", 1)[1], "IDENTITY_MISMATCH")
        policy = self.call(
            "iam",
            "GetRolePolicy",
            dict(RoleName=role, PolicyName=cfg["guard_policy_name"]),
        )
        c._require(
            policy["RoleName"] == role
            and policy["PolicyName"] == cfg["guard_policy_name"],
            "IDENTITY_MISMATCH",
        )
        body = decode(urllib.parse.unquote(policy["PolicyDocument"]).encode())
        return body == guard_policy(cfg["workload_metric"]["namespace"]), utc(
            self.clock()
        )

    def metric(self, cfg: dict, *, workload: bool) -> tuple[bool, str]:
        end = utc(self.clock())
        start = metric_start(self.completed, end, self.age)
        params = dict(
            Namespace=cfg["namespace"],
            MetricName=cfg["name"],
            StartTime=start,
            EndTime=end,
            Period="60",
            **{
                "Statistics.member.1": "Maximum",
                "Dimensions.member.1.Name": "InstanceId",
                "Dimensions.member.1.Value": self.cfg["instance_id"],
            },
        )
        if workload:
            params.update(
                {
                    "Statistics.member.2": "Minimum",
                    "Dimensions.member.2.Name": "RunId",
                    "Dimensions.member.2.Value": self.run_id,
                    "Dimensions.member.3.Name": "UnitId",
                    "Dimensions.member.3.Value": self.unit_id,
                }
            )
        value = self.call("monitoring", "GetMetricStatistics", params)
        c._require(value["Label"] == cfg["name"], "METRIC_ID_MISMATCH")
        points = [
            (native_time(p["Timestamp"]), float(p[statistic]))
            for p in value["Datapoints"]
            for statistic in (("Minimum", "Maximum") if workload else ("Maximum",))
        ]
        return samples(points, cfg, start, utc(self.clock()), self.age)

    def monitoring(self) -> tuple[bool, str]:
        machine = self.instance()
        if machine["monitoring"]["state"] != "enabled":
            return False, utc(self.clock())
        alarms = self.call(
            "monitoring",
            "DescribeAlarms",
            {"AlarmNames.member.1": self.cfg["alarm_name"]},
        )["MetricAlarms"]
        c._require(len(alarms) == 1, "MONITORING_ID_MISMATCH")
        alarm = alarms[0]
        c._require(
            alarm["AlarmName"] == self.cfg["alarm_name"], "MONITORING_ID_MISMATCH"
        )
        expected = dict(
            Namespace="AWS/EC2",
            MetricName="StatusCheckFailed",
            Statistic="Maximum",
            Period="60",
            EvaluationPeriods="2",
            ComparisonOperator="GreaterThanThreshold",
            TreatMissingData="breaching",
            Dimensions=[dict(Name="InstanceId", Value=self.cfg["instance_id"])],
        )
        if (
            not zero_threshold(alarm.get("Threshold"))
            or any(alarm.get(k) != v for k, v in expected.items())
            or alarm["StateValue"] == "ALARM"
        ):
            return False, utc(self.clock())
        c._require(alarm["StateValue"] == "OK", "MONITORING_UNKNOWN")
        return self.metric(
            dict(namespace="AWS/EC2", name="StatusCheckFailed", minimum=0, maximum=0),
            workload=False,
        )

    def workload(self) -> tuple[bool, str]:
        return self.metric(self.cfg["workload_metric"], workload=True)

    def backup(self) -> tuple[bool, str]:
        cfg = self.cfg["backup"]
        base = f"https://backup.{self.scope['region']}.amazonaws.com"

        def get(path):
            return decode(
                self.request("backup", self.scope["region"], "GET", base + path)
            )

        value = get(
            "/backup/plans/" + cfg["plan_id"] + "/selections/" + cfg["selection_id"]
        )
        c._require(
            value["BackupPlanId"] == cfg["plan_id"]
            and value["SelectionId"] == cfg["selection_id"],
            "BACKUP_ID_MISMATCH",
        )
        selection = value["BackupSelection"]
        c._require(
            not any(
                selection.get(k) for k in ("ListOfTags", "NotResources", "Conditions")
            ),
            "BACKUP_CONTEXT_UNSUPPORTED",
        )
        c._require(
            selection["Resources"] == [self.resource_arn]
            and selection["IamRoleArn"] == cfg["role_arn"],
            "BACKUP_ID_MISMATCH",
        )
        # Fixed, one-page bounded discovery. An incomplete page blocks; never
        # silently select a healthy point from an unknown remainder.
        query = urllib.parse.urlencode(
            dict(
                resourceArn=self.resource_arn,
                backupPlanId=cfg["plan_id"],
                backupVaultAccountId=self.scope["account_id"],
                createdAfter=int(
                    max(c._utc(self.completed).timestamp(), self.clock() - self.age)
                ),
                maxResults=100,
            ),
            quote_via=urllib.parse.quote,
        )
        listing = get(
            "/backup-vaults/" + cfg["vault_name"] + "/recovery-points/?" + query
        )
        c._require(not listing.get("NextToken"), "PAGINATION_INCOMPLETE")
        points = listing["RecoveryPoints"]
        c._require(type(points) is list and 0 < len(points) <= 100, "SIGNAL_MISSING")
        c._unique([point["RecoveryPointArn"] for point in points])
        for recovery in points:
            c._match(
                recovery["RecoveryPointArn"],
                r"arn:aws:backup:"
                + re.escape(self.scope["region"])
                + ":"
                + self.scope["account_id"]
                + r":recovery-point:[A-Za-z0-9-]+",
            )
            c._require(
                recovery["ResourceArn"] == self.resource_arn
                and recovery["BackupVaultName"] == cfg["vault_name"]
                and recovery["CreatedBy"]["BackupPlanId"] == cfg["plan_id"],
                "BACKUP_ID_MISMATCH",
            )
            samples(
                [(native_time(recovery["CreationDate"]), 1)],
                dict(minimum=1, maximum=1),
                self.completed,
                utc(self.clock()),
                self.age,
            )
        recovery = max(points, key=lambda point: point["CreationDate"])
        c._enum(recovery["Status"], ("COMPLETED", "PARTIAL", "DELETING", "EXPIRED"))
        healthy, stamp = samples(
            [(native_time(recovery["CompletionDate"]), 1)],
            dict(minimum=1, maximum=1),
            self.completed,
            utc(self.clock()),
            self.age,
        )
        return healthy and recovery["Status"] == "COMPLETED" and recovery[
            "IsEncrypted"
        ] is True, stamp


def resolve_resources(executor, cfg: dict) -> dict:
    """Resolve only selectors in the immutable compiled stack, never input physical IDs."""
    from aws_execution import exact_artifacts

    configuration(cfg)
    template = local_decode(exact_artifacts(executor.root, executor.request_ref)[1])
    resources = template["Resources"]
    result = copy.deepcopy(cfg)

    def resolve(logical: str, typ: str) -> str:
        c._require(
            logical in resources and resources[logical]["Type"] == typ,
            "COMPILED_SELECTOR_MISMATCH",
        )
        if typ == "AWS::EC2::SecurityGroup":
            c._require(
                resources[logical]["Properties"]["VpcId"] == cfg["vpc_id"],
                "COMPILED_SELECTOR_MISMATCH",
            )
        if typ == "AWS::Backup::BackupSelection":
            c._require(
                resources[logical]["Properties"]["BackupPlanId"]
                == cfg["backup"]["plan_id"],
                "COMPILED_SELECTOR_MISMATCH",
            )
        detail = executor.read(
            "DescribeStackResource",
            dict(StackName=executor.stack_id, LogicalResourceId=logical),
        )["StackResourceDetail"]
        c._require(
            detail["StackId"] == executor.stack_id
            and detail["LogicalResourceId"] == logical
            and detail["ResourceType"] == typ
            and detail["ResourceStatus"] in ("CREATE_COMPLETE", "UPDATE_COMPLETE"),
            "STACK_RESOURCE_MISMATCH",
        )
        return detail["PhysicalResourceId"]

    result["instance_id"] = resolve(
        result.pop("instance_logical_id"), "AWS::EC2::Instance"
    )
    result["security_group_ids"] = [
        resolve(v, "AWS::EC2::SecurityGroup")
        for v in result.pop("security_group_logical_ids")
    ]
    result["alarm_name"] = resolve(
        result.pop("alarm_logical_id"), "AWS::CloudWatch::Alarm"
    )
    if "backup" in result:
        result["backup"]["selection_id"] = resolve(
            result["backup"].pop("selection_logical_id"), "AWS::Backup::BackupSelection"
        )
    return result


def current_operation(executor) -> str:
    """The latest native stack operation must still be the original execution.

    DescribeStackEvents is reverse chronological. Filtering by the old token
    first would adopt resources from a later UPDATE under the old completion.
    """
    stack = executor.stack()
    c._require(
        stack is not None
        and stack["StackStatus"] in ("CREATE_COMPLETE", "UPDATE_COMPLETE"),
        "NATIVE_OPERATION_NOT_SUCCEEDED",
    )
    events = executor.read("DescribeStackEvents", dict(StackName=executor.stack_id))[
        "StackEvents"
    ]
    c._require(
        type(events) is list and 0 < len(events) <= 4096, "ORIGINAL_OPERATION_REQUIRED"
    )
    times = [native_time(event["Timestamp"]) for event in events]
    c._require(times == sorted(times, reverse=True), "EVENT_ORDER_INVALID")
    stacks = [
        event
        for event in events
        if event.get("ResourceType") == "AWS::CloudFormation::Stack"
    ]
    c._require(bool(stacks), "ORIGINAL_OPERATION_REQUIRED")
    latest = stacks[0]
    c._require(
        latest.get("StackId") == executor.stack_id
        and latest.get("LogicalResourceId")
        == executor.request["scope"]["deployment_scope"]
        and latest.get("ClientRequestToken") == executor.token
        and latest["ResourceStatus"] == stack["StackStatus"],
        "ORIGINAL_OPERATION_SUPERSEDED",
    )
    completed = native_time(latest["Timestamp"])
    c._require(
        all(
            event.get("StackId") == executor.stack_id
            and (stamp < completed or event.get("ClientRequestToken") == executor.token)
            for event, stamp in zip(events, times)
        ),
        "ORIGINAL_OPERATION_SUPERSEDED",
    )
    return completed



def profile_preview_readback(executor, preview_ref: dict) -> None:
    """Cloud profile v2: authenticate executed preview semantics, not local hashes.

    Deliberately separate from apply's AVAILABLE-only readback: an executed
    Change Set must be EXECUTE_COMPLETE. Never rewrite that native status.
    """
    from cloud_verification import _bound_preview

    request, root = executor.request, executor.root
    preview = _bound_preview(root, request, executor.request_ref, preview_ref)
    semantic = decode(c.read_verified(root, preview["changes"]))
    c._record(semantic, dict(schema=lambda v: c._enum(v, ("aws-exact-preview/v1",)),
                            request=c._ref, create=lambda v: c._require(type(v) is dict),
                            asset=lambda v: c._require(type(v) is dict), template_sha256=c._sha,
                            change_set_arn=c._text, stack_id=c._text, scope=c._scope,
                            changes=lambda v: c._list(v, lambda x: c._require(type(x) is dict), 1),
                            no_change=c._boolean))
    data = executor.check()
    asset, create = semantic["asset"], semantic["create"]
    c._require(semantic["request"] == executor.request_ref
               and semantic["scope"] == request["scope"]
               and semantic["template_sha256"] == digest(data[1])
               and semantic["change_set_arn"] == preview["preview_identity"] == executor.native_id
               and semantic["stack_id"] == executor.stack_id
               and semantic["no_change"] is False
               and create == executor.create_params(data, asset, "UPDATE" if executor.control.existing_stack_id else "CREATE"),
               "PROFILE_PREVIEW_NATIVE_BINDING")
    # Bind exact immutable asset bytes as well as the original template.
    executor.native.bucket_check(executor.credentials)
    executor.native.read_object(asset, executor.credentials, data[1])
    value = executor.describe()
    template = executor.read("GetTemplate", dict(StackName=executor.stack_id,
                             ChangeSetName=executor.native_id, TemplateStage="Original"))
    expected = dict(ChangeSetId=executor.native_id, StackId=executor.stack_id,
                    ChangeSetName=executor.name, StackName=create["StackName"],
                    Description=create["Description"], Capabilities=create["Capabilities"],
                    Parameters=create["Parameters"], Status="CREATE_COMPLETE", ExecutionStatus="EXECUTE_COMPLETE")
    c._require(all(value.get(k) == v for k, v in expected.items())
               and sorted(value.get("Tags", []), key=lambda v: v["Key"]) == sorted(create["Tags"], key=lambda v: v["Key"])
               and type(template["TemplateBody"]) is str and template["TemplateBody"].encode() == data[1],
               "PROFILE_PREVIEW_NATIVE_BINDING")
    c._require(not any(value.get(k) for k in ("IncludeNestedStacks", "ImportExistingResources", "ParentChangeSetId", "RootChangeSetId", "OnStackFailure", "NotificationARNs", "DeploymentConfig"))
               and not value.get("RollbackConfiguration", {}).get("RollbackTriggers", [])
               and value.get("DeploymentMode", "REVERT_DRIFT") == "REVERT_DRIFT", "PROFILE_PREVIEW_NATIVE_BINDING")
    actual = value.get("Changes")
    c._require(type(actual) is list and actual
               and sorted(actual, key=lambda v: v["ResourceChange"]["LogicalResourceId"]) == semantic["changes"],
               "PROFILE_PREVIEW_SEMANTICS_MISMATCH")
    resources = decode(data[1])["Resources"]
    c._unique([item["ResourceChange"]["LogicalResourceId"] for item in actual])
    for item in actual:
        change = item["ResourceChange"]
        c._require(set(item) == {"Type", "ResourceChange"} and item["Type"] == "Resource"
                   and change["LogicalResourceId"] in resources
                   and resources[change["LogicalResourceId"]]["Type"] == change["ResourceType"]
                   and change["Action"] in ("Add", "Modify") and change.get("Replacement", "False") == "False"
                   and not change.get("ChangeSetId") and not change.get("ModuleInfo")
                   and change.get("PolicyAction") in (None, "Retain"), "PROFILE_PREVIEW_POLICY_DENIED")
        if change["Action"] == "Modify":
            c._require(bool(change.get("Details")) and change.get("Scope") == ["Properties"]
                       and all(d.get("Evaluation") == "Static" and d.get("ChangeSource") == "DirectModification"
                               and d["Target"].get("Attribute") == "Properties"
                               and d["Target"].get("RequiresRecreation") == "Never" for d in change["Details"]),
                       "PROFILE_PREVIEW_POLICY_DENIED")


def observe(executor, output: str, phase: str) -> dict:
    """Fresh federation + original execute intent; imported result files never prove health."""
    from cloud_authorization import (
        AwsIdentity,
        GitHubAdmission,
        HttpsTransport as AuthHttps,
    )

    executor.trusted_binding()
    root, request = executor.root, executor.request
    output_path(root, request, output)
    output_path(root, request, output + ".manifest.json")
    c.verify_local_context(root, request, execution=True)
    cfg = local_decode(
        c.read_verified(root, request["local_context"]["provider_config"])
    )
    c._require("observation" in cfg, "OBSERVATION_CONFIGURATION_REQUIRED")
    observation = cfg["observation"]
    configuration(observation)
    path = executor.directory + "/execute-submission.json"
    journal = local_decode(read_bytes(root, path))
    c._require(
        journal["schema"] == "aws-submission/v1"
        and journal["mutation"] == "execute"
        and journal["request"] == executor.request_ref
        and journal["scope"] == request["scope"]
        and journal["client_token"] == executor.token,
        "ORIGINAL_OPERATION_REQUIRED",
    )
    executor.arn(journal["native_operation_id"], "changeSet", executor.name)
    executor.arn(journal["stack_id"], "stack", request["scope"]["deployment_scope"])
    executor.native_id, executor.stack_id = (
        journal["native_operation_id"],
        journal["stack_id"],
    )
    p = executor.boundary.policy
    github = GitHubAdmission(p, executor.boundary.runtime, executor.boundary.transport)
    now = int(executor.clock())
    token, claims = github.oidc(now)
    principal, end, credentials = AwsIdentity.exchange(
        p, token, claims, executor.boundary.transport, now
    )
    executor.credentials, executor.lease = credentials, min(end, claims["exp"])
    trace_start = len(executor.native.trace)
    completed = current_operation(executor)
    observation = resolve_resources(executor, observation)
    profile = c.read_artifact(
        root,
        c._file_ref(request["verification_profile"]),
        "cloud-verification-profile/v1",
    )
    if profile["id"] == "cloud-compute" and profile["version"] != "1":
        profile_preview_readback(executor, journal["preview"])
    collector = Collector(
        request["scope"],
        observation,
        credentials,
        principal=principal,
        completed=completed,
        age=profile["max_age_seconds"],
        clock=executor.clock,
        transport=executor.native.transport,
        run_id=request["run_id"],
        unit_id=request["unit_id"],
    )

    def recheck():
        if profile["id"] == "cloud-compute" and profile["version"] != "1":
            profile_preview_readback(executor, journal["preview"])
        c._require(
            current_operation(executor) == completed, "ORIGINAL_OPERATION_SUPERSEDED"
        )
        c._require(
            resolve_resources(executor, cfg["observation"]) == observation,
            "ORIGINAL_RESOURCE_DRIFT",
        )
        return [
            dict(
                locator=v["url"],
                request_sha256=v["request_sha256"],
                response_sha256=v["response_sha256"],
                http_status=v["status"],
            )
            for v in executor.native.trace[trace_start:]
        ]

    collector.directory = output
    collector.lease = executor.lease
    native = (
        type(executor.native.transport) is HttpsTransport
        and type(executor.boundary.transport) is AuthHttps
    )
    return publish_collection(
        executor,
        output,
        phase,
        collector,
        principal=principal,
        native_id=executor.native_id,
        resources=[collector.resource_arn],
        completed=completed,
        native=native,
        preview_ref=journal["preview"],
        publish_json=publish_json,
        publish_bytes=publish_bytes,
        scan=safe_publication,
        recheck=recheck,
    )
