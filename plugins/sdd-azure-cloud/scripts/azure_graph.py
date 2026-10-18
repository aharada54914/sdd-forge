"""Bounded Azure ARM graph policy; never executes ARM functions or provider APIs.

Resolve ordinary Bicep parameter/variable/format/resourceId expressions and inline
incremental modules. Unknown functions, linked templates, loops and cross-scope
modules block. This is local policy interpretation, not Azure ARM validation.
"""
from __future__ import annotations

import re
from typing import Any

from cloud import c

NIC = "Microsoft.Network/networkInterfaces"
VM = "Microsoft.Compute/virtualMachines"
EXT = VM + "/extensions"
DCR = "Microsoft.Insights/dataCollectionRuleAssociations"
BACKUP = "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems"
NSG = "Microsoft.Network/networkSecurityGroups"
DEPLOYMENT = "Microsoft.Resources/deployments"
VERSIONS = {NIC: {"2024-05-01"}, VM: {"2024-07-01"}, EXT: {"2024-07-01"},
            DCR: {"2023-03-11"}, BACKUP: {"2024-04-01"}, NSG: {"2024-05-01"}}


def require(condition: object, code: str = "ARM_POLICY_DENIED") -> None:
    c._require(condition, code)


def fields(value: Any, required: set[str], optional: set[str] | None = None) -> None:
    require(type(value) is dict and required <= set(value) <= required | (optional or set()))


def resource_id(scope: dict, typ: str, name: str) -> str:
    parts = typ.split("/")
    names = name.split("/")
    require(len(parts) == len(names) + 1 and parts[0].startswith("Microsoft."))
    return ("/subscriptions/" + scope["account_id"] + "/resourceGroups/" + scope["deployment_scope"] +
            "/providers/" + parts[0] + "/" + "/".join(x for pair in zip(parts[1:], names) for x in pair))


class Expressions:
    """Small parser for a closed ARM function subset; no eval or Python formatting."""
    def __init__(self, parameters: dict, variables: dict, scope: dict):
        self.parameters = parameters
        self.variables = variables
        self.scope = scope
        self.active: set[str] = set()
        self.steps = 0

    def value(self, value: Any) -> Any:
        self.steps += 1
        require(self.steps <= 20000, "ARM_EXPRESSION_LIMIT")
        if type(value) is dict:
            result = {}
            for key, child in value.items():
                resolved = self.value(key)
                require(type(resolved) is str and resolved not in result)
                result[resolved] = self.value(child)
            return result
        if type(value) is list:
            return [self.value(v) for v in value]
        if type(value) is not str or not value.startswith("["):
            return value
        if value.startswith("[["):
            return value[1:]
        require(value.endswith("]"), "ARM_EXPRESSION_UNSUPPORTED")
        source = value[1:-1]
        tokens = re.findall(r"'(?:[^']|'')*'|-?\d+|[A-Za-z_][A-Za-z_0-9]*|[(),.\[\]]|\S", source)
        index = 0

        def expression(depth: int = 0) -> Any:
            nonlocal index
            require(depth <= 64, "ARM_EXPRESSION_LIMIT")
            require(index < len(tokens), "ARM_EXPRESSION_UNSUPPORTED")
            token = tokens[index]
            index += 1
            if token.startswith("'") and token.endswith("'"):
                result = token[1:-1].replace("''", "'")
            elif re.fullmatch(r"-?\d+", token):
                result = int(token)
            else:
                require(index < len(tokens) and tokens[index] == "(", "ARM_EXPRESSION_UNSUPPORTED")
                index += 1
                args = []
                if index < len(tokens) and tokens[index] != ")":
                    args.append(expression(depth + 1))
                    while index < len(tokens) and tokens[index] == ",":
                        index += 1
                        args.append(expression(depth + 1))
                require(index < len(tokens) and tokens[index] == ")", "ARM_EXPRESSION_UNSUPPORTED")
                index += 1
                result = self.call(token, args)
            while index < len(tokens) and tokens[index] in (".", "["):
                bracket = tokens[index] == "["
                index += 1
                require(index < len(tokens))
                key = expression(depth + 1) if bracket else tokens[index]
                if not bracket:
                    index += 1
                else:
                    require(index < len(tokens) and tokens[index] == "]")
                    index += 1
                require(type(result) is dict and key in result or
                        type(result) is list and type(key) is int and 0 <= key < len(result))
                result = result[key]
            return result

        result = expression()
        require(index == len(tokens), "ARM_EXPRESSION_UNSUPPORTED")
        return result

    def call(self, name: str, args: list) -> Any:
        name = name.lower()
        if name == "parameters" and len(args) == 1:
            require(args[0] in self.parameters)
            return self.parameters[args[0]]
        if name == "variables" and len(args) == 1:
            key = args[0]
            require(key in self.variables and key not in self.active)
            self.active.add(key)
            result = self.value(self.variables[key])
            self.active.remove(key)
            return result
        if name == "resourcegroup" and not args:
            return dict(name=self.scope["deployment_scope"], location=self.scope["region"],
                        id="/subscriptions/" + self.scope["account_id"] + "/resourceGroups/" + self.scope["deployment_scope"])
        if name == "subscription" and not args:
            return dict(subscriptionId=self.scope["account_id"], id="/subscriptions/" + self.scope["account_id"])
        if name == "resourceid" and len(args) >= 2 and all(type(x) is str for x in args):
            return resource_id(self.scope, args[0], "/".join(args[1:]))
        if name == "format" and args and type(args[0]) is str:
            require(not re.search(r"\{(?!\d+\})|(?<!\d)\}", args[0]), "ARM_EXPRESSION_UNSUPPORTED")
            def substitute(match):
                i = int(match[1]) + 1
                require(i < len(args) and type(args[i]) in (str, int))
                return str(args[i])
            return re.sub(r"\{(\d+)\}", substitute, args[0])
        if name == "concat" and all(type(x) is str for x in args):
            return "".join(args)
        if name in ("tolower", "toupper") and len(args) == 1 and type(args[0]) is str:
            return args[0].lower() if name == "tolower" else args[0].upper()
        if name == "if" and len(args) == 3 and type(args[0]) is bool:
            return args[1] if args[0] else args[2]
        if name == "equals" and len(args) == 2:
            return type(args[0]) is type(args[1]) and args[0] == args[1]
        if name in ("true", "false") and not args:
            return name == "true"
        raise c.ContractError("ARM_EXPRESSION_UNSUPPORTED")


def flatten(template: dict, parameters: dict, scope: dict, allowed: set[str], depth: int = 0) -> list[dict]:
    require(depth <= 8, "ARM_EXPRESSION_LIMIT")
    fields(template, {"$schema", "contentVersion", "resources"},
           {"metadata", "parameters", "variables", "outputs", "languageVersion"})
    require(template["$schema"] == "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#")
    require(template.get("languageVersion", "1.0") in ("1.0", "2.0"))
    declared = template.get("parameters", {})
    require(set(parameters) == set(declared))
    for key, definition in declared.items():
        fields(definition, {"type"}, {"metadata", "allowedValues", "minLength", "maxLength", "minValue", "maxValue"})
        kind = definition["type"].lower()
        require(kind in ("string", "int", "bool", "object", "array"))
        require(type(parameters[key]) is {"string": str, "int": int, "bool": bool, "object": dict, "array": list}[kind])
        if "allowedValues" in definition:
            require(parameters[key] in definition["allowedValues"])
    resolver = Expressions(parameters, template.get("variables", {}), scope)
    require(type(resolver.variables) is dict)
    for key in resolver.variables:
        resolver.call("variables", [key])
    outputs = template.get("outputs", {})
    require(type(outputs) is dict)
    for output in outputs.values():
        fields(output, {"type", "value"}, {"metadata"})
        kind = output["type"].lower()
        require(kind in ("string", "int", "bool", "object", "array"))
        value = resolver.value(output["value"])
        require(type(value) is {"string": str, "int": int, "bool": bool, "object": dict, "array": list}[kind])
    raw = template["resources"]
    require(type(raw) in (dict, list))
    resources = list(raw.values()) if type(raw) is dict else raw
    require(len(resources) <= 100)
    result = []
    for item in resources:
        require(type(item) is dict)
        if item.get("type") == DEPLOYMENT:
            fields(item, {"type", "apiVersion", "name", "properties"}, {"dependsOn"})
            require(DEPLOYMENT in allowed)
            require(type(resolver.value(item["name"])) is str)
            dependencies = resolver.value(item.get("dependsOn", []))
            require(type(dependencies) is list and all(type(d) is str for d in dependencies))
            require(item["apiVersion"] == "2025-04-01")
            props = item["properties"]
            fields(props, {"expressionEvaluationOptions", "mode", "parameters", "template"})
            require(props["mode"] == "Incremental" and props["expressionEvaluationOptions"] == {"scope": "inner"})
            module_parameters = {}
            for key, value in props["parameters"].items():
                fields(value, {"value"})
                module_parameters[key] = resolver.value(value["value"])
            result.extend(flatten(props["template"], module_parameters, scope, allowed, depth + 1))
        else:
            result.append(resolver.value(item))
    require(len(result) <= 100)
    return result


def validate_graph(template: dict, parameters: dict, request: dict, policy: dict, ownership: dict) -> None:
    scope = request["scope"]
    allowed = set(policy["allowed_resource_types"])
    resources = flatten(template, parameters, scope, allowed)
    existing = {r["resource_id"].lower(): r for r in ownership["existing_resources"]}
    seen: set[str] = set()
    by_type: dict[str, list[dict]] = {}
    for r in resources:
        fields(r, {"type", "apiVersion", "name", "properties"},
               {"location", "tags", "dependsOn", "identity", "scope", "sku", "zones"})
        typ, name = r["type"], r["name"]
        require(type(typ) is str and type(name) is str)
        rid = resource_id(scope, typ, name) if "scope" not in r else r["scope"] + "/providers/" + typ + "/" + name
        require(rid.lower() not in existing, "EXISTING_RESOURCE_MUTATION")
        # A parent replacement can destroy referenced children just as a direct write can.
        require(not any(key.startswith(rid.lower() + "/") for key in existing), "EXISTING_RESOURCE_MUTATION")
        require(rid.lower() not in seen, "DUPLICATE_RESOURCE")
        seen.add(rid.lower())
        require(typ != "Microsoft.Network/publicIPAddresses", "PUBLIC_NETWORK_DENIED")
        require(typ in allowed and typ in VERSIONS and r["apiVersion"] in VERSIONS[typ])
        require("location" not in r or r["location"] == scope["region"])
        require("identity" not in r or typ == VM)
        require("scope" not in r or typ == DCR)
        require("sku" not in r and "zones" not in r)
        if "tags" in r:
            require(type(r["tags"]) is dict and all(type(k) is str and type(v) is str for k, v in r["tags"].items()))
        by_type.setdefault(typ, []).append(r)
    for typ in (VM, NIC, EXT, DCR, BACKUP):
        require(len(by_type.get(typ, [])) == 1, "REQUIRED_RESOURCE_MISSING")
    vm, nic, extension, dcr, backup = [by_type[t][0] for t in (VM, NIC, EXT, DCR, BACKUP)]
    require(vm["name"] == parameters["vmName"])
    vm_id = resource_id(scope, VM, vm["name"])
    nic_id = resource_id(scope, NIC, nic["name"])
    require(vm.get("identity") == {"type": "UserAssigned", "userAssignedIdentities": {parameters["identityId"]: {}}})
    props = vm["properties"]
    fields(props, {"hardwareProfile", "storageProfile", "osProfile", "networkProfile"})
    require(props["hardwareProfile"] == {"vmSize": parameters["vmSize"]})
    storage = props["storageProfile"]
    fields(storage, {"imageReference", "osDisk"}, {"dataDisks"})
    require(storage["imageReference"] == {"id": parameters["imageId"]} and storage.get("dataDisks", []) == [])
    disk = storage["osDisk"]
    fields(disk, {"createOption", "managedDisk", "deleteOption"}, {"diskSizeGB", "name"})
    require(disk["createOption"] == "FromImage" and disk["deleteOption"] == "Detach")
    fields(disk["managedDisk"], {"storageAccountType"})
    require(disk["managedDisk"]["storageAccountType"] in ("Standard_LRS", "StandardSSD_LRS", "Premium_LRS"))
    if "diskSizeGB" in disk:
        require(type(disk["diskSizeGB"]) is int and 1 <= disk["diskSizeGB"] <= 4095)
    os_profile = props["osProfile"]
    fields(os_profile, {"computerName", "adminUsername", "linuxConfiguration"})
    require(os_profile["computerName"] == vm["name"] and os_profile["adminUsername"] == parameters["adminUsername"])
    require(os_profile["linuxConfiguration"] == {"disablePasswordAuthentication": True, "ssh": {"publicKeys": [
        {"path": "/home/" + parameters["adminUsername"] + "/.ssh/authorized_keys", "keyData": parameters["adminPublicKey"]}]}})
    require(props["networkProfile"] == {"networkInterfaces": [{"id": nic_id}]})
    np = nic["properties"]
    fields(np, {"enableIPForwarding", "ipConfigurations"}, {"enableAcceleratedNetworking", "networkSecurityGroup"})
    require(np["enableIPForwarding"] is False)
    require("enableAcceleratedNetworking" not in np or type(np["enableAcceleratedNetworking"]) is bool)
    require(type(np["ipConfigurations"]) is list and len(np["ipConfigurations"]) == 1)
    ip = np["ipConfigurations"][0]
    fields(ip, {"name", "properties"})
    require("publicIPAddress" not in ip["properties"], "PUBLIC_NETWORK_DENIED")
    require(ip["properties"] == {"privateIPAllocationMethod": "Dynamic", "subnet": {"id": parameters["subnetId"]}})
    for nsg in by_type.get(NSG, []):
        fields(nsg["properties"], {"securityRules"})
        for rule in nsg["properties"]["securityRules"]:
            fields(rule, {"name", "properties"})
            rule_props = rule["properties"]
            fields(rule_props, {"priority", "access", "direction", "protocol", "sourceAddressPrefix", "sourcePortRange",
                                "destinationAddressPrefix", "destinationPortRange"})
            # No new inbound Allow rule is authorized by this version's private policy.
            require(not (rule_props["access"] == "Allow" and rule_props["direction"] == "Inbound"), "PUBLIC_NETWORK_DENIED")
            require(rule_props["access"] == "Deny" and rule_props["direction"] in ("Inbound", "Outbound"))
    if "networkSecurityGroup" in np:
        require(np["networkSecurityGroup"] in [{"id": resource_id(scope, NSG, n["name"])} for n in by_type.get(NSG, [])])
    require(extension["name"].split("/")[0] == vm["name"])
    ep = extension["properties"]
    require(ep == {"publisher": "Microsoft.Azure.Monitor", "type": "AzureMonitorLinuxAgent", "typeHandlerVersion": "1.0",
                   "autoUpgradeMinorVersion": False, "enableAutomaticUpgrade": False,
                   "settings": {"authentication": {"managedIdentity": {"identifier-name": "mi_res_id", "identifier-value": parameters["identityId"]}}}})
    require(dcr.get("scope") == vm_id and dcr["properties"] == {"dataCollectionRuleId": parameters["dataCollectionRuleId"]})
    container = "iaasvmcontainer;iaasvmcontainerv2;" + scope["deployment_scope"] + ";" + vm["name"]
    protected = "vm;iaasvmcontainerv2;" + scope["deployment_scope"] + ";" + vm["name"]
    require(backup["name"] == parameters["vaultName"] + "/Azure/" + container + "/" + protected)
    require(backup["properties"] == {"protectedItemType": VM, "sourceResourceId": vm_id, "policyId": parameters["backupPolicyId"]})
    attachments = [(parameters["subnetId"], NIC, nic["name"]), (parameters["identityId"], VM, vm["name"]),
                   (parameters["dataCollectionRuleId"], DCR, dcr["name"]), (parameters["backupPolicyId"], BACKUP, vm["name"])]
    for rid, typ, name in attachments:
        require(existing[rid.lower()]["attachments"] == [{"resource_type": typ, "name": name}], "ATTACHMENT_DENIED")
