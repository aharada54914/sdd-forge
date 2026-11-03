"""Fixed read-only ARM VM collector. Effective-network POST is a native read.

For a positive permission check, the fresh observer MUST be the VM's sole
user-assigned identity. ARM's caller-permissions endpoint then describes that
workload identity, not the deployment service principal. Only finite explicit
control-plane actions below are supported; wildcards, data rights and incomplete
pagination block. Roles are never inferred from names or desired IaC.
"""

from __future__ import annotations

import base64
import ipaddress
from typing import Callable
import urllib.parse

from cloud import (
    c,
    decode as local_decode,
    read_bytes,
    output_path,
    publish_json,
    publish_bytes,
    safe_publication,
)
from azure_arm import HttpsTransport, ORIGIN
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


def resource_id(value: str) -> None:
    c._match(
        value,
        r"/subscriptions/[a-f0-9-]{36}/resourceGroups/[A-Za-z0-9_-]+/providers/[A-Za-z.]+/(?:[A-Za-z0-9_.;-]+/)+[A-Za-z0-9_.;-]+",
    )
    c._require(
        not any(x in value for x in ("/../", "/./", "//")), "RESOURCE_ID_INVALID"
    )


def configuration(cfg: dict) -> None:
    c._record(
        cfg,
        dict(
            vm_id=resource_id,
            nic_id=resource_id,
            subnet_id=resource_id,
            identity_id=resource_id,
            association_id=resource_id,
            data_collection_rule_id=resource_id,
            monitoring_workspace_id=resource_id,
            workload_metric=metric_config,
        ),
        dict(
            backup=lambda v: c._record(
                v,
                dict(
                    protected_item_id=resource_id,
                    policy_id=resource_id,
                ),
            )
        ),
    )
    types = dict(
        vm_id="/providers/Microsoft.Compute/virtualMachines/",
        nic_id="/providers/Microsoft.Network/networkInterfaces/",
        identity_id="/providers/Microsoft.ManagedIdentity/userAssignedIdentities/",
        data_collection_rule_id="/providers/Microsoft.Insights/dataCollectionRules/",
        monitoring_workspace_id="/providers/Microsoft.OperationalInsights/workspaces/",
    )
    for key, typ in types.items():
        c._require(
            typ in cfg[key] and "/" not in cfg[key].split(typ)[1],
            "RESOURCE_TYPE_INVALID",
        )
    c._require(
        cfg["association_id"].startswith(
            cfg["vm_id"]
            + "/providers/Microsoft.Insights/dataCollectionRuleAssociations/"
        ),
        "ASSOCIATION_ID_INVALID",
    )
    if "backup" in cfg:
        backup = cfg["backup"]
        c._require(
            "/protectedItems/" in backup["protected_item_id"],
            "BACKUP_ID_INVALID",
        )


def permission_ceiling(resource: str, cfg: dict) -> set[str]:
    """Finite read/metric actions for this exact workload scope; no wildcard policy engine."""
    actions = {
        "Microsoft.Authorization/permissions/read",
        *AUDIT_ACTIONS,
        *DEPLOYMENT_READS,
    }
    if resource == cfg["vm_id"]:
        actions |= {
            "Microsoft.Compute/virtualMachines/read",
            "Microsoft.Compute/virtualMachines/instanceView/read",
            "Microsoft.Insights/metrics/read",
            "Microsoft.Insights/metrics/write",
        }
    elif resource == cfg["nic_id"]:
        actions |= {
            "Microsoft.Network/networkInterfaces/read",
            "Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action",
        }
    elif resource == cfg["identity_id"]:
        actions.add("Microsoft.ManagedIdentity/userAssignedIdentities/read")
    elif resource == cfg["association_id"]:
        actions.add("Microsoft.Insights/dataCollectionRuleAssociations/read")
    elif resource == cfg["data_collection_rule_id"]:
        actions.add("Microsoft.Insights/dataCollectionRules/read")
    elif resource == cfg.get("backup", {}).get("protected_item_id"):
        actions |= {
            "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/read",
            "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/recoveryPoints/read",
        }
    elif "backup" in cfg and resource.startswith(
        cfg["backup"]["protected_item_id"] + "/recoveryPoints/"
    ):
        actions |= permission_ceiling(cfg["backup"]["protected_item_id"], cfg)
    else:
        raise c.ContractError("PERMISSION_SCOPE_UNSUPPORTED")
    return actions


DEPLOYMENT_READS = frozenset(
    {
        "Microsoft.Resources/deployments/read",
        "Microsoft.Resources/deployments/operations/read",
    }
)
AUDIT_ACTIONS = frozenset(
    {
        "Microsoft.Authorization/roleAssignments/read",
        "Microsoft.Authorization/roleDefinitions/read",
    }
)


def explicit_actions(permissions: list[dict]) -> set[str]:
    c._require(
        type(permissions) is list and 0 < len(permissions) <= 128, "PERMISSIONS_MISSING"
    )
    actions: set[str] = set()
    for permission in permissions:
        c._record(
            permission,
            {
                k: lambda v: c._list(v, c._text)
                for k in ("actions", "notActions", "dataActions", "notDataActions")
            },
        )
        c._require(
            not permission["notActions"]
            and not permission["dataActions"]
            and not permission["notDataActions"],
            "PERMISSION_CONTEXT_UNSUPPORTED",
        )
        c._require(
            all("*" not in a and "?" not in a for a in permission["actions"]),
            "PERMISSION_CONTEXT_UNSUPPORTED",
        )
        actions.update(permission["actions"])
    return actions


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
        configuration(cfg)
        prefix = "/subscriptions/" + scope["account_id"] + "/resourceGroups/"
        resources = [
            cfg[k]
            for k in (
                "vm_id",
                "nic_id",
                "subnet_id",
                "identity_id",
                "association_id",
                "data_collection_rule_id",
                "monitoring_workspace_id",
            )
        ]
        resources += list(cfg.get("backup", {}).values())
        c._require(
            all(v.startswith(prefix) for v in resources), "RESOURCE_SCOPE_MISMATCH"
        )
        c._require(
            cfg["vm_id"].startswith(prefix + scope["deployment_scope"] + "/"),
            "RESOURCE_SCOPE_MISMATCH",
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
        self.provenance_trace: list[dict] = []
        self.directory = ""
        self.lease = int(clock()) + 120

    def get(
        self,
        path: str,
        version: str,
        *,
        network: bool = False,
        params: dict | None = None,
    ) -> dict:
        # No URL is taken from a response/input. Every caller constructs a fixed
        # supported resource operation from validated exact IDs.
        subscription = "/subscriptions/" + self.scope["account_id"]
        assignment_path = (
            subscription + "/providers/Microsoft.Authorization/roleAssignments"
        )
        definition_prefix = (
            subscription + "/providers/Microsoft.Authorization/roleDefinitions/"
        )
        if path == assignment_path:
            c._require(
                params == {"$filter": "assignedTo('" + self.principal + "')"},
                "READ_OPERATION_DENIED",
            )
        elif path.startswith(definition_prefix):
            c._match(path[len(definition_prefix) :], r"[a-f0-9-]{36}")
            c._require(params is None, "READ_OPERATION_DENIED")
        else:
            resource_id(path)
        c._require(
            version
            in (
                "2024-07-01",
                "2024-05-01",
                "2023-03-11",
                "2023-10-01",
                "2024-04-01",
                "2023-01-31",
                "2022-04-01",
            ),
            "API_VERSION_UNSUPPORTED",
        )
        method = "POST" if network else "GET"
        c._require(
            not network
            or path == self.cfg["nic_id"] + "/effectiveNetworkSecurityGroups",
            "READ_OPERATION_DENIED",
        )
        url = (
            ORIGIN
            + path
            + "?"
            + urllib.parse.urlencode(
                {"api-version": version, **(params or {})}, quote_via=urllib.parse.quote
            )
        )
        c._require(int(self.clock()) < self.lease, "READ_CREDENTIAL_EXPIRED")
        response = self.transport.request(
            method,
            url,
            {
                "Authorization": "Bearer " + self.credentials["AZURE_ACCESS_TOKEN"],
                "Content-Type": "application/json",
            },
            None,
        )
        c._require(int(self.clock()) < self.lease, "READ_CREDENTIAL_EXPIRED")
        c._require(
            type(response.body) is bytes and len(response.body) <= c.MAX_BYTES,
            "NATIVE_RESPONSE_INVALID",
        )
        self.trace.append(
            dict(
                locator=url,
                request_sha256=digest(b""),
                response_sha256=digest(response.body),
                http_status=response.status,
            )
        )
        # 202 is a pending read, not a completed network result. No unvalidated
        # Location follow-up. Retry by the same fixed read on a later collection.
        c._require(response.status == 200, "NATIVE_READ_UNAVAILABLE")
        value = decode(response.body)
        c._require(
            type(value) is dict and not value.get("nextLink"), "PAGINATION_INCOMPLETE"
        )
        return value

    def vm(self) -> dict:
        value = self.get(self.cfg["vm_id"], "2024-07-01")
        c._require(
            value["id"] == self.cfg["vm_id"]
            and value["location"] == self.scope["region"],
            "RESOURCE_ID_MISMATCH",
        )
        return value

    def resource(self) -> tuple[bool, str]:
        self.trace.extend(self.provenance_trace)
        vm = self.vm()
        state = self.get(self.cfg["vm_id"] + "/instanceView", "2024-07-01")
        statuses = [v["code"] for v in state["statuses"]]
        power = [v for v in statuses if v.startswith("PowerState/")]
        c._require(len(power) == 1, "RESOURCE_STATE_UNKNOWN")
        c._enum(
            power[0],
            (
                "PowerState/running",
                "PowerState/starting",
                "PowerState/stopping",
                "PowerState/stopped",
                "PowerState/deallocating",
                "PowerState/deallocated",
            ),
        )
        c._enum(
            vm["properties"]["provisioningState"],
            ("Succeeded", "Failed", "Canceled", "Creating", "Updating", "Deleting"),
        )
        return vm["properties"][
            "provisioningState"
        ] == "Succeeded" and "PowerState/running" in statuses, utc(self.clock())

    def network(self) -> tuple[bool, str]:
        cfg = self.cfg
        vm = self.vm()
        c._require(
            vm["properties"]["networkProfile"]["networkInterfaces"]
            == [dict(id=cfg["nic_id"])],
            "NETWORK_CONTEXT_UNSUPPORTED",
        )
        nic = self.get(cfg["nic_id"], "2024-05-01")
        c._require(
            nic["id"] == cfg["nic_id"]
            and nic["properties"]["virtualMachine"]["id"] == cfg["vm_id"],
            "NETWORK_ID_MISMATCH",
        )
        ips = nic["properties"]["ipConfigurations"]
        c._require(bool(ips), "NETWORK_STATE_MISSING")
        for ip in ips:
            p = ip["properties"]
            c._require(p["subnet"]["id"] == cfg["subnet_id"], "NETWORK_ID_MISMATCH")
            if (
                p.get("publicIPAddress")
                or ipaddress.ip_address(p["privateIPAddress"]).version != 4
            ):
                return False, utc(self.clock())
        effective = self.get(
            cfg["nic_id"] + "/effectiveNetworkSecurityGroups",
            "2024-05-01",
            network=True,
        )["value"]
        c._require(bool(effective), "EFFECTIVE_NETWORK_MISSING")
        private = [
            ipaddress.IPv4Network(n)
            for n in (
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16",
                "168.63.129.16/32",
            )
        ]
        for group in effective:
            association = group["association"]
            c._require(
                association.get("networkInterface", {}).get("id") == cfg["nic_id"]
                or association.get("subnet", {}).get("id") == cfg["subnet_id"],
                "NETWORK_ID_MISMATCH",
            )
            rules = group["effectiveSecurityRules"]
            c._require(bool(rules), "EFFECTIVE_NETWORK_MISSING")
            for rule in rules:
                c._enum(rule["direction"], ("Inbound", "Outbound"))
                c._enum(rule["access"], ("Allow", "Deny"))
                if rule["access"] == "Deny":
                    continue
                key = (
                    "expandedSourceAddressPrefix"
                    if rule["direction"] == "Inbound"
                    else "expandedDestinationAddressPrefix"
                )
                expanded = rule[key]
                c._require(
                    type(expanded) is list and bool(expanded),
                    "NETWORK_CONTEXT_UNSUPPORTED",
                )
                for prefix in expanded:
                    network = ipaddress.ip_network(prefix)
                    if not isinstance(network, ipaddress.IPv4Network) or not any(
                        network.subnet_of(n) for n in private
                    ):
                        return False, utc(self.clock())
        return True, utc(self.clock())

    def identity(self) -> tuple[bool, str]:
        cfg = self.cfg
        vm = self.vm()
        identity = vm["identity"]
        c._require(
            identity["type"] == "UserAssigned"
            and set(identity["userAssignedIdentities"]) == {cfg["identity_id"]},
            "IDENTITY_CONTEXT_UNSUPPORTED",
        )
        native = self.get(cfg["identity_id"], "2023-01-31")
        c._require(
            native["id"] == cfg["identity_id"]
            and native["properties"]["principalId"] == self.principal
            and identity["userAssignedIdentities"][cfg["identity_id"]]["principalId"]
            == self.principal,
            "WORKLOAD_OBSERVER_PRINCIPAL_REQUIRED",
        )
        targets = [
            cfg[k]
            for k in (
                "vm_id",
                "nic_id",
                "identity_id",
                "association_id",
                "data_collection_rule_id",
            )
        ]
        if "backup" in cfg:
            targets.append(cfg["backup"]["protected_item_id"])
        first, grants = self.permission_closure(targets)
        for target in targets:
            permissions = self.get(
                target + "/providers/Microsoft.Authorization/permissions", "2022-04-01"
            )["value"]
            actual = explicit_actions(permissions)
            if not actual <= permission_ceiling(target, cfg):
                return False, utc(self.clock())
            c._require(actual == grants[target], "PERMISSION_CLOSURE_MISMATCH")
        # Bounded stability check, not an atomic snapshot or a cached-token revocation proof.
        last, _ = self.permission_closure(targets)
        c._require(first == last, "PERMISSION_CLOSURE_DRIFT")
        return True, utc(self.clock())

    def permission_closure(
        self, targets: list[str]
    ) -> tuple[dict, dict[str, set[str]]]:
        """Complete subscription-scoped direct RBAC closure, never a global IAM engine.

        assignedTo includes inherited/descendant and transitive group assignments.
        Group/conditional/delegated contexts are deliberately unsupported. Native
        pagination blocks rather than silently truncating or following arbitrary URLs.
        """
        c._match(self.principal, r"[a-f0-9-]{36}")
        subscription = "/subscriptions/" + self.scope["account_id"]
        assignments = self.get(
            subscription + "/providers/Microsoft.Authorization/roleAssignments",
            "2022-04-01",
            params={"$filter": "assignedTo('" + self.principal + "')"},
        )["value"]
        c._require(
            type(assignments) is list and 0 < len(assignments) <= 128,
            "PERMISSIONS_MISSING",
        )
        c._unique([row["id"] for row in assignments])
        definitions: dict[str, dict] = {}
        grants = {target: set(AUDIT_ACTIONS | DEPLOYMENT_READS) for target in targets}
        audit: set[str] = set()
        group_reads: set[str] = set()
        group = subscription + "/resourceGroups/" + self.scope["deployment_scope"]
        for row in assignments:
            prop = row["properties"]
            scope = prop["scope"]
            c._require(
                scope in (subscription, group) or scope in targets,
                "PERMISSION_SCOPE_UNSUPPORTED",
            )
            c._match(row["name"], r"[a-f0-9-]{36}")
            c._require(
                row["type"] == "Microsoft.Authorization/roleAssignments"
                and row["id"]
                == scope
                + "/providers/Microsoft.Authorization/roleAssignments/"
                + row["name"]
                and prop["principalId"] == self.principal
                and prop["principalType"] == "ServicePrincipal"
                and not prop.get("condition")
                and not prop.get("conditionVersion")
                and not prop.get("delegatedManagedIdentityResourceId"),
                "PERMISSION_CONTEXT_UNSUPPORTED",
            )
            role_id = prop["roleDefinitionId"]
            prefix = (
                subscription + "/providers/Microsoft.Authorization/roleDefinitions/"
            )
            c._require(
                type(role_id) is str and role_id.startswith(prefix), "ROLE_ID_MISMATCH"
            )
            c._match(role_id[len(prefix) :], r"[a-f0-9-]{36}")
            if role_id not in definitions:
                role = self.get(role_id, "2022-04-01")
                c._require(
                    role["id"] == role_id
                    and role["name"] == role_id[len(prefix) :]
                    and role["type"] == "Microsoft.Authorization/roleDefinitions",
                    "ROLE_ID_MISMATCH",
                )
                definitions[role_id] = role
            actions = explicit_actions(
                definitions[role_id]["properties"]["permissions"]
            )
            if scope == subscription:
                c._require(actions <= AUDIT_ACTIONS, "PERMISSION_SCOPE_UNSUPPORTED")
                audit |= actions
            elif scope == group:
                c._require(actions <= DEPLOYMENT_READS, "PERMISSION_SCOPE_UNSUPPORTED")
                group_reads |= actions
            else:
                c._require(
                    actions <= permission_ceiling(scope, self.cfg),
                    "PERMISSION_CONTEXT_UNSUPPORTED",
                )
                grants[scope] |= actions
        c._require(
            audit == AUDIT_ACTIONS and group_reads == DEPLOYMENT_READS,
            "PERMISSION_CLOSURE_MISMATCH",
        )
        return dict(assignments=assignments, definitions=definitions), grants

    def metric(self, cfg: dict, *, workload: bool) -> tuple[bool, str]:
        end = utc(self.clock())
        start = metric_start(self.completed, end, self.age)
        params = dict(
            metricnamespace=cfg["namespace"],
            metricnames=cfg["name"],
            aggregation="Minimum,Maximum" if workload else "Maximum",
            timespan=start + "/" + end,
            interval="PT1M",
            AutoAdjustTimegrain="false",
            ValidateDimensions="true",
        )
        if workload:
            params["$filter"] = (
                f"RunId eq '{self.run_id}' and UnitId eq '{self.unit_id}'"
            )
        response = self.get(
            self.cfg["vm_id"] + "/providers/Microsoft.Insights/metrics",
            "2023-10-01",
            params=params,
        )
        c._require(
            response["namespace"] == cfg["namespace"]
            and response["resourceregion"] == self.scope["region"]
            and response["interval"] == "PT1M"
            and response["timespan"] == params["timespan"],
            "METRIC_CONTEXT_MISMATCH",
        )
        values = response["value"]
        c._require(
            len(values) == 1 and values[0]["name"]["value"] == cfg["name"],
            "METRIC_ID_MISMATCH",
        )
        metric = values[0]
        c._require(
            metric["id"]
            == self.cfg["vm_id"]
            + "/providers/Microsoft.Insights/metrics/"
            + cfg["name"],
            "METRIC_ID_MISMATCH",
        )
        c._require(
            not metric.get("errorCode") or metric["errorCode"] == "Success",
            "METRIC_UNAVAILABLE",
        )
        series = metric["timeseries"]
        c._require(len(series) == 1, "METRIC_CONTEXT_UNSUPPORTED")
        c._unique([v["name"]["value"] for v in series[0].get("metadatavalues", [])])
        metadata = {
            v["name"]["value"]: v["value"] for v in series[0].get("metadatavalues", [])
        }
        c._require(
            metadata
            == ({"RunId": self.run_id, "UnitId": self.unit_id} if workload else {}),
            "METRIC_ID_MISMATCH",
        )
        points = [
            (native_time(p["timeStamp"]), p[statistic])
            for p in series[0]["data"]
            if "maximum" in p or "minimum" in p
            for statistic in (("minimum", "maximum") if workload else ("maximum",))
        ]
        return samples(points, cfg, start, utc(self.clock()), self.age)

    def monitoring(self) -> tuple[bool, str]:
        cfg = self.cfg
        association = self.get(cfg["association_id"], "2023-03-11")
        c._require(association["id"] == cfg["association_id"], "MONITORING_ID_MISMATCH")
        if (
            association["properties"]["dataCollectionRuleId"]
            != cfg["data_collection_rule_id"]
        ):
            return False, utc(self.clock())
        rule = self.get(cfg["data_collection_rule_id"], "2023-03-11")
        c._require(
            rule["id"] == cfg["data_collection_rule_id"]
            and rule["location"] == self.scope["region"]
            and rule["kind"] == "Linux",
            "MONITORING_ID_MISMATCH",
        )
        props = rule["properties"]
        c._require(
            set(props)
            <= {
                "description",
                "immutableId",
                "metadata",
                "endpoints",
                "provisioningState",
                "dataSources",
                "destinations",
                "dataFlows",
            },
            "MONITORING_CONTEXT_UNSUPPORTED",
        )
        sources = props["dataSources"]
        destinations = props["destinations"]
        c._require(
            set(sources) == {"performanceCounters"}
            and len(sources["performanceCounters"]) == 1
            and set(destinations) == {"logAnalytics"}
            and len(destinations["logAnalytics"]) == 1,
            "MONITORING_CONTEXT_UNSUPPORTED",
        )
        counter = sources["performanceCounters"][0]
        destination = destinations["logAnalytics"][0]
        c._record(
            counter,
            dict(
                name=c._text,
                streams=lambda v: c._list(v, c._text),
                samplingFrequencyInSeconds=c._integer,
                counterSpecifiers=lambda v: c._list(v, c._text),
            ),
        )
        c._record(
            destination,
            dict(name=c._text, workspaceResourceId=resource_id),
            dict(workspaceId=c._text),
        )
        if not (
            props["provisioningState"] == "Succeeded"
            and counter["streams"] == ["Microsoft-Perf"]
            and counter["samplingFrequencyInSeconds"] == 60
            and counter["counterSpecifiers"]
            == ["\\Processor(_Total)\\% Processor Time"]
            and destination["workspaceResourceId"] == cfg["monitoring_workspace_id"]
            and props["dataFlows"]
            == [dict(streams=["Microsoft-Perf"], destinations=[destination["name"]])]
        ):
            return False, utc(self.clock())
        # Platform CPU is a real received signal, not a desired agent configuration.
        return self.metric(
            dict(
                namespace="Microsoft.Compute/virtualMachines",
                name="Percentage CPU",
                minimum=0,
                maximum=100,
            ),
            workload=False,
        )

    def workload(self) -> tuple[bool, str]:
        return self.metric(self.cfg["workload_metric"], workload=True)

    def recovery_points(self) -> list[dict]:
        parent = self.cfg["backup"]["protected_item_id"]
        points = self.get(parent + "/recoveryPoints", "2024-04-01")["value"]
        c._require(
            type(points) is list and 0 < len(points) <= 4096, "RECOVERY_POINTS_MISSING"
        )
        c._unique([point["id"] for point in points])
        for point in points:
            resource_id(point["id"])
            c._require(
                point["id"].startswith(parent + "/recoveryPoints/")
                and "/" not in point["id"][len(parent + "/recoveryPoints/") :],
                "BACKUP_ID_MISMATCH",
            )
        return points

    def backup(self) -> tuple[bool, str]:
        cfg = self.cfg["backup"]
        item = self.get(cfg["protected_item_id"], "2024-04-01")
        c._require(item["id"] == cfg["protected_item_id"], "BACKUP_ID_MISMATCH")
        p = item["properties"]
        c._require(
            p["virtualMachineId"] == self.cfg["vm_id"]
            and p["policyId"] == cfg["policy_id"],
            "BACKUP_ID_MISMATCH",
        )
        c._enum(p["lastBackupStatus"], ("Completed", "Failed", "InProgress"))
        c._enum(
            p["protectionState"],
            (
                "Protected",
                "ProtectionError",
                "ProtectionStopped",
                "ProtectionPaused",
                "IRPending",
            ),
        )
        points = self.recovery_points()
        # Native lists include history; only points created after original apply
        # completion are candidates. A page continuation already blocks in get().
        recent = [
            point
            for point in points
            if c._utc(native_time(point["properties"]["recoveryPointTime"]))
            >= c._utc(self.completed)
        ]
        c._require(bool(recent), "STALE_SIGNAL")
        recovery = max(
            recent,
            key=lambda point: c._utc(
                native_time(point["properties"]["recoveryPointTime"])
            ),
        )
        _, stamp = samples(
            [
                (native_time(p["lastBackupTime"]), 1),
                (native_time(recovery["properties"]["recoveryPointTime"]), 1),
            ],
            dict(minimum=1, maximum=1),
            self.completed,
            utc(self.clock()),
            self.age,
        )
        return p["protectionState"] == "Protected" and p[
            "lastBackupStatus"
        ] == "Completed", stamp


def current_deployment(executor, credentials: dict, trace: list[dict]) -> dict:
    """Bounded complete RG deployment history; unknown or overlapping writers block.

    ARM template timestamp is used only to order deployments, never as completion.
    Exclusive governed writer is still a prerequisite; direct resource mutations
    outside that boundary cannot be proven absent by deployment history.
    """
    native = executor.client.native_id
    prefix = native.rsplit("/", 1)[0] + "/"
    url = ORIGIN + prefix.rstrip("/") + "?api-version=2025-04-01"
    response = executor.client.call("GET", url, credentials, executor.request_id)
    trace.append(
        dict(
            locator=url,
            request_sha256=digest(b""),
            response_sha256=digest(response.body),
            http_status=response.status,
        )
    )
    c._require(response.status == 200, "DEPLOYMENT_HISTORY_UNAVAILABLE")
    value = decode(response.body)
    rows = value["value"]
    c._require(
        not value.get("nextLink") and type(rows) is list and 0 < len(rows) <= 128,
        "PAGINATION_INCOMPLETE",
    )
    c._unique([row["id"] for row in rows])
    originals = [row for row in rows if row["id"] == native]
    c._require(
        len(originals) == 1
        and originals[0]["properties"]["provisioningState"] == "Succeeded",
        "ORIGINAL_OPERATION_REQUIRED",
    )
    original_time = native_time(originals[0]["properties"]["timestamp"])
    c._require(
        c._utc(original_time) <= c._utc(utc(executor.clock())),
        "DEPLOYMENT_TIME_INVALID",
    )
    for row in rows:
        c._require(
            row["id"].startswith(prefix) and "/" not in row["id"][len(prefix) :],
            "DEPLOYMENT_SCOPE_MISMATCH",
        )
        if row["id"] != native:
            c._require(
                row["properties"]["provisioningState"]
                in ("Succeeded", "Failed", "Canceled")
                and native_time(row["properties"]["timestamp"]) < original_time,
                "ORIGINAL_OPERATION_SUPERSEDED",
            )
    return value


def bind_original_resources(
    executor, cfg: dict, compiled: list[dict], credentials: dict, trace: list[dict]
) -> None:
    from azure_graph import resource_id as compiled_id

    current_deployment(executor, credentials, trace)
    scope = executor.request["scope"]
    expected = {
        (
            r["scope"] + "/providers/" + r["type"] + "/" + r["name"]
            if "scope" in r
            else compiled_id(scope, r["type"], r["name"])
        ): r["type"]
        for r in compiled
    }
    selected = {
        cfg["vm_id"]: "Microsoft.Compute/virtualMachines",
        cfg["nic_id"]: "Microsoft.Network/networkInterfaces",
        cfg["association_id"]: "Microsoft.Insights/dataCollectionRuleAssociations",
    }
    if "backup" in cfg:
        selected[cfg["backup"]["protected_item_id"]] = (
            "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems"
        )
    c._require(
        all(expected.get(rid) == typ for rid, typ in selected.items()),
        "COMPILED_RESOURCE_MISMATCH",
    )
    url = ORIGIN + executor.client.native_id + "/operations?api-version=2025-04-01"
    response = executor.client.call("GET", url, credentials, executor.request_id)
    trace.append(
        dict(
            locator=url,
            request_sha256=digest(b""),
            response_sha256=digest(response.body),
            http_status=response.status,
        )
    )
    c._require(response.status == 200, "ORIGINAL_OPERATIONS_UNAVAILABLE")
    value = decode(response.body)
    c._require(
        not value.get("nextLink")
        and type(value["value"]) is list
        and 0 < len(value["value"]) <= 4096,
        "PAGINATION_INCOMPLETE",
    )
    c._unique([op["id"] for op in value["value"]])
    matches = set()
    for op in value["value"]:
        c._require(
            op["id"] == executor.client.native_id + "/operations/" + op["operationId"],
            "ORIGINAL_OPERATION_MISMATCH",
        )
        properties = op["properties"]
        target = properties.get("targetResource", {})
        if target.get("id") in selected:
            c._require(
                target["resourceType"] == selected[target["id"]]
                and properties["provisioningState"] == "Succeeded"
                and properties["provisioningOperation"] == "Create",
                "ORIGINAL_RESOURCE_MISMATCH",
            )
            matches.add(target["id"])
    c._require(matches == set(selected), "ORIGINAL_RESOURCE_MISMATCH")


def original_apply_completion(
    executor, run_id: int, preview: dict, trace: list[dict]
) -> str:
    """Authenticated job end is a conservative upper bound, not an ARM timestamp guess.

    Only the exact new fixed-phase generated JSON workflow is supported. Old YAML
    or ambiguous apply/reconcile workflows block and must be regenerated/pinned.
    """
    from azure_governed import workflow_template

    p = executor.boundary.policy
    c._require(type(run_id) is int and run_id > 0, "ORIGINAL_RUN_REQUIRED")
    c._ref(preview)
    base = "https://api.github.com/repos/" + p.repository

    def get(url):
        raw = executor.boundary.transport.request(
            "GET",
            url,
            {
                "Authorization": "Bearer " + executor.boundary.runtime.github_token,
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        trace.append(
            dict(
                locator=url,
                request_sha256=digest(b""),
                response_sha256=digest(raw),
                http_status=200,
            )
        )
        return decode(raw)

    run = get(base + "/actions/runs/" + str(run_id))
    c._require(
        run["id"] == run_id
        and run["run_attempt"] == 1
        and run["event"] == "workflow_dispatch"
        and run["status"] == "completed"
        and run["conclusion"] == "success"
        and run["path"] == p.workflow
        and run["head_sha"] == p.workflow_revision
        and run["display_title"]
        == "cloud:" + executor.request_ref["sha256"] + ":" + preview["sha256"]
        and all(
            run[key]["id"] == p.repository_id and run[key]["full_name"] == p.repository
            for key in ("repository", "head_repository")
        ),
        "ORIGINAL_RUN_MISMATCH",
    )
    file = get(base + "/contents/" + p.workflow + "?ref=" + p.workflow_revision)
    c._require(
        file["type"] == "file"
        and file["path"] == p.workflow
        and file["encoding"] == "base64",
        "WORKFLOW_PROOF_REQUIRED",
    )
    workflow = decode(
        base64.b64decode(file["content"].replace("\n", ""), validate=True)
    )
    checkout = workflow["jobs"]["apply"]["steps"][0]["with"]
    input_repo = workflow["jobs"]["prepare"]["steps"][1]["env"]["ARTIFACT_REPOSITORY"]
    scope = executor.request["scope"]
    expected = workflow_template(
        executor_repository=checkout["repository"],
        executor_revision=checkout["ref"],
        subscription=scope["account_id"],
        region=scope["region"],
        input_repository=input_repo,
    )
    c._require(workflow == expected, "FIXED_WORKFLOW_REQUIRED")
    jobs = get(
        base + "/actions/runs/" + str(run_id) + "/attempts/1/jobs?per_page=100&page=1"
    )
    c._require(
        type(jobs["total_count"]) is int
        and 1 <= jobs["total_count"] <= 100
        and type(jobs["jobs"]) is list
        and len(jobs["jobs"]) == jobs["total_count"],
        "PAGINATION_INCOMPLETE",
    )
    c._unique([job["id"] for job in jobs["jobs"]])
    applies = [job for job in jobs["jobs"] if job["name"] == "apply"]
    c._require(len(applies) == 1, "ORIGINAL_APPLY_JOB_REQUIRED")
    job = applies[0]
    c._require(
        job["run_id"] == run_id
        and job["run_attempt"] == 1
        and job["head_sha"] == p.workflow_revision
        and job["status"] == "completed"
        and job["conclusion"] == "success",
        "ORIGINAL_APPLY_JOB_REQUIRED",
    )
    steps = [
        step
        for step in job["steps"]
        if step["name"] == expected["jobs"]["apply"]["steps"][1]["name"]
    ]
    c._require(
        len(steps) == 1
        and steps[0]["status"] == "completed"
        and steps[0]["conclusion"] == "success",
        "ORIGINAL_APPLY_STEP_REQUIRED",
    )
    completed = native_time(job["completed_at"])
    c._require(
        c._utc(native_time(job["started_at"]))
        <= c._utc(native_time(steps[0]["started_at"]))
        <= c._utc(native_time(steps[0]["completed_at"]))
        <= c._utc(completed)
        <= c._utc(utc(executor.clock())),
        "COMPLETION_WINDOW_INVALID",
    )
    return completed


def recheck_deployment(
    executor, cfg: dict, compiled: list[dict], credentials: dict
) -> list[dict]:
    trace: list[dict] = []
    bind_original_resources(executor, cfg, compiled, credentials, trace)
    return trace


def observe(executor, output: str, phase: str) -> dict:
    from cloud_authorization import (
        AzureIdentity,
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
    operation = local_decode(
        read_bytes(root, executor.directory + "/deployment-submission.json")
    )
    c._require(
        operation["schema"] == "azure-submission/v1"
        and operation["request"] == executor.request_ref
        and operation["scope"] == request["scope"]
        and operation["native_operation_id"] == executor.client.native_id
        and operation["request_id"] == executor.request_id,
        "ORIGINAL_OPERATION_REQUIRED",
    )
    p = executor.boundary.policy
    github = GitHubAdmission(p, executor.boundary.runtime, executor.boundary.transport)
    now = int(executor.clock())
    token, claims = github.oidc(now)
    principal, end, credentials = AzureIdentity.exchange(
        p, token, claims, executor.boundary.transport, now
    )
    c._require(
        int(executor.clock()) < min(end, claims["exp"]), "READ_CREDENTIAL_EXPIRED"
    )
    response = executor.client.call(
        "GET", executor.client.url, credentials, executor.request_id
    )
    c._require(response.status == 200, "NATIVE_OPERATION_UNAVAILABLE")
    value = decode(response.body)
    c._require(
        value["id"] == executor.client.native_id
        and value["properties"]["provisioningState"] == "Succeeded"
        and observation["vm_id"]
        in [r["id"] for r in value["properties"]["outputResources"]],
        "NATIVE_OPERATION_NOT_SUCCEEDED",
    )
    # The local receipt selects a candidate run only. Authenticated GitHub
    # metadata and the exact protected workflow prove its fixed apply semantics.
    receipt_path = (
        executor.directory
        + "/"
        + request["unit_id"]
        + ".apply.deploy.authorization.json"
    )
    receipt = c.parse_artifact(
        read_bytes(root, receipt_path), "cloud-authorization-receipt/v1"
    )
    c._require(
        receipt["request"] == executor.request_ref
        and receipt["preview"] == operation["preview"]
        and receipt["operation"] == "apply"
        and receipt["scope"] == request["scope"],
        "ORIGINAL_RECEIPT_MISMATCH",
    )
    trace: list[dict] = []
    data = executor.check()
    c._require(
        operation["body_sha256"] == digest(executor.body(data, preview=False)),
        "ORIGINAL_BODY_MISMATCH",
    )
    bind_original_resources(executor, observation, data[3], credentials, trace)
    completed = original_apply_completion(
        executor, int(receipt["ci"]["run_id"]), operation["preview"], trace
    )
    c._require(
        int(executor.clock()) < min(end, claims["exp"]), "READ_CREDENTIAL_EXPIRED"
    )
    profile = c.read_artifact(
        root,
        c._file_ref(request["verification_profile"]),
        "cloud-verification-profile/v1",
    )
    collector = Collector(
        request["scope"],
        observation,
        credentials,
        principal=principal,
        completed=completed,
        age=profile["max_age_seconds"],
        clock=executor.clock,
        transport=executor.client.transport,
        run_id=request["run_id"],
        unit_id=request["unit_id"],
    )

    def recheck():
        c._require(
            int(executor.clock()) < min(end, claims["exp"]), "READ_CREDENTIAL_EXPIRED"
        )
        checks = recheck_deployment(executor, observation, data[3], credentials)
        c._require(
            int(executor.clock()) < min(end, claims["exp"]), "READ_CREDENTIAL_EXPIRED"
        )
        return checks

    collector.provenance_trace = trace
    collector.directory = output
    collector.lease = min(end, claims["exp"])
    native = (
        type(executor.client.transport) is HttpsTransport
        and type(executor.boundary.transport) is AuthHttps
    )
    return publish_collection(
        executor,
        output,
        phase,
        collector,
        principal=principal,
        native_id=executor.client.native_id,
        resources=[observation["vm_id"]],
        completed=completed,
        native=native,
        preview_ref=operation["preview"],
        publish_json=publish_json,
        publish_bytes=publish_bytes,
        scan=safe_publication,
        recheck=recheck,
    )
