"""Bounded structural policy for the supported private EC2 CloudFormation graph.

No golden-template comparison: logical IDs/order may vary. Unsupported executable
surfaces, resource types and intrinsics block rather than evade inspection.
"""
from __future__ import annotations

from dataclasses import dataclass
import ipaddress
import re
from typing import Any
from cloud import c


@dataclass(frozen=True)
class Symbol:
    text: str
    references: frozenset[tuple[str, str]]


def resource_ref(name: str, attribute: str = 'Ref') -> Symbol:
    return Symbol('@' + name, frozenset({(name, attribute)}))


def compose(separator: str, parts: list) -> str | Symbol:
    c._require(all(isinstance(x, (str, Symbol)) for x in parts), 'CFN_EXPRESSION_UNSUPPORTED')
    text = separator.join(x.text if isinstance(x, Symbol) else x for x in parts)
    c._require(len(text) <= 8192, 'CFN_EXPRESSION_LIMIT')
    refs = frozenset(ref for part in parts if isinstance(part, Symbol) for ref in part.references)
    return Symbol(text, refs) if refs else text


class Expressions:
    def __init__(self, resources: dict, parameters: dict, defaults: dict | None = None):
        self.resources = resources
        self.p = parameters
        self.nodes = 0
        self.defaults = defaults or {}

    def value(self, v: Any, depth: int = 0) -> Any:
        self.nodes += 1
        c._require(depth <= 48 and self.nodes <= 100000, 'CFN_EXPRESSION_LIMIT')
        if type(v) is str:
            c._require('{{resolve:' not in v, 'CFN_EXPRESSION_UNSUPPORTED')
            return v
        if v is None or type(v) in (int, bool):
            return v
        if type(v) is list:
            return [self.value(x, depth + 1) for x in v]
        c._require(type(v) is dict, 'CFN_EXPRESSION_UNSUPPORTED')
        if 'Ref' in v:
            c._require(set(v) == {'Ref'} and type(v['Ref']) is str, 'CFN_EXPRESSION_UNSUPPORTED')
            ref = v['Ref']
            pseudo = {'AWS::AccountId': self.p['account'], 'AWS::Region': self.p['region'],
                      'AWS::Partition': 'aws', 'AWS::StackName': self.p['stackName']}
            c._require(ref in pseudo or ref in self.resources or ref in self.defaults, 'CFN_EXPRESSION_UNSUPPORTED')
            return pseudo[ref] if ref in pseudo else self.defaults[ref] if ref in self.defaults else resource_ref(ref)
        if 'Fn::GetAtt' in v:
            c._require(set(v) == {'Fn::GetAtt'}, 'CFN_EXPRESSION_UNSUPPORTED')
            args = v['Fn::GetAtt']
            if type(args) is str:
                args = args.split('.')
            c._require(type(args) is list and len(args) == 2 and all(type(x) is str for x in args), 'CFN_EXPRESSION_UNSUPPORTED')
            rid, attr = args
            c._require(rid in self.resources and self.resources[rid]['Type'] == 'AWS::EC2::SecurityGroup'
                       and attr == 'GroupId', 'CFN_EXPRESSION_UNSUPPORTED')
            return resource_ref(rid, attr)
        if 'Fn::Join' in v:
            c._require(set(v) == {'Fn::Join'}, 'CFN_EXPRESSION_UNSUPPORTED')
            args = self.value(v['Fn::Join'], depth + 1)
            c._require(type(args) is list and len(args) == 2 and type(args[0]) is str and
                       type(args[1]) is list, 'CFN_EXPRESSION_UNSUPPORTED')
            return compose(args[0], args[1])
        if 'Fn::Sub' in v:
            c._require(set(v) == {'Fn::Sub'}, 'CFN_EXPRESSION_UNSUPPORTED')
            args = v['Fn::Sub']
            text, mapping = (args, {}) if type(args) is str else args
            c._require(type(text) is str and type(mapping) is dict, 'CFN_EXPRESSION_UNSUPPORTED')
            parts = []
            start = 0
            for match in re.finditer(r'\$\{([^}]+)\}', text):
                parts.append(text[start:match.start()])
                key = match[1]
                if key in mapping:
                    result = self.value(mapping[key], depth + 1)
                elif '.' in key:
                    result = self.value({'Fn::GetAtt': key}, depth + 1)
                else:
                    result = self.value({'Ref': key}, depth + 1)
                parts.append(result)
                start = match.end()
            parts.append(text[start:])
            return compose('', parts)
        c._require(not any(k.startswith('Fn::') for k in v), 'CFN_EXPRESSION_UNSUPPORTED')
        return {k: self.value(x, depth + 1) for k, x in v.items()}


def fields(obj: Any, required: set[str], optional: set[str] | None = None) -> None:
    c._require(type(obj) is dict and required <= set(obj) <= required | (optional or set()), 'CFN_STRUCTURE_UNSUPPORTED')


def private_cidr(value: Any) -> None:
    c._require(type(value) is str, 'PUBLIC_NETWORK_DENIED')
    try:
        network = ipaddress.ip_network(value)
        ranges = [ipaddress.IPv4Network(v) for v in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]
        c._require(isinstance(network, ipaddress.IPv4Network) and any(network.subnet_of(r) for r in ranges), 'PUBLIC_NETWORK_DENIED')
    except ValueError:
        raise c.ContractError('PUBLIC_NETWORK_DENIED') from None


def validate_graph(template: dict, p: dict, policy: dict, owner: dict) -> None:
    fields(template, {'Resources'}, {'AWSTemplateFormatVersion', 'Description', 'Outputs', 'Parameters'})
    resources = template['Resources']
    c._require(type(resources) is dict and 1 <= len(resources) <= 512, 'CFN_STRUCTURE_UNSUPPORTED')
    defaults = {}
    for key, param in template.get('Parameters', {}).items():
        fields(param, {'Type', 'Default'}, {'Description'})
        c._require(param['Type'] == 'AWS::EC2::Image::Id' and param['Default'] == p['imageId'], 'CFN_PARAMETER_UNSUPPORTED')
        defaults[key] = param['Default']
    ex = Expressions(resources, p, defaults)
    resolved = ex.value(template)
    for output in resolved.get('Outputs', {}).values():
        fields(output, {'Value'}, {'Description'})
    types = ('AWS::EC2::Instance', 'AWS::EC2::SecurityGroup', 'AWS::CloudWatch::Alarm', 'AWS::Backup::BackupSelection')
    protected = ('AWS::EC2::VPC', 'AWS::EC2::Subnet', 'AWS::IAM::Role', 'AWS::IAM::InstanceProfile',
                 'AWS::Backup::BackupPlan', 'AWS::Backup::BackupVault')
    public = ('AWS::EC2::EIP', 'AWS::EC2::EIPAssociation', 'AWS::EC2::InternetGateway',
              'AWS::EC2::Route', 'AWS::EC2::NatGateway', 'AWS::EC2::SecurityGroupIngress')
    records = resolved['Resources']
    for logical, record in records.items():
        c._match(logical, r'[A-Za-z][A-Za-z0-9]{0,254}')
        fields(record, {'Type', 'Properties'}, {'DependsOn', 'DeletionPolicy', 'UpdateReplacePolicy', 'Metadata'})
        typ = record['Type']
        c._require(typ not in protected, 'EXISTING_RESOURCE_MUTATION')
        c._require(typ not in public, 'PUBLIC_NETWORK_DENIED')
        c._require(typ in types and typ in policy['allowed_resource_types'], 'RESOURCE_TYPE_UNSUPPORTED')
        c._require(set(record.get('Metadata', {})) <= {'aws:cdk:path'}, 'CFN_EXECUTABLE_UNSUPPORTED')
        for key in ('DeletionPolicy', 'UpdateReplacePolicy'):
            if key in record:
                c._require(record[key] == 'Retain', 'DESTRUCTIVE_POLICY_DENIED')
        depends = record.get('DependsOn', [])
        depends = [depends] if type(depends) is str else depends
        c._require(type(depends) is list and all(d in records for d in depends), 'CFN_STRUCTURE_UNSUPPORTED')

    def attachment(rid, typ, logical):
        found = next((r for r in owner['existing_resources'] if r['resource_id'] == rid), None)
        c._require(found is not None and {'resource_type': typ, 'name': logical} in found['attachments'], 'ATTACHMENT_DENIED')

    groups, machines, alarms, backups = [{k: r['Properties'] for k, r in records.items() if r['Type'] == typ} for typ in types[1::-1] + types[2:]]
    c._require(bool(groups) and bool(machines) and bool(alarms), 'LOCAL_POLICY_DENIED')
    for logical, group in groups.items():
        fields(group, {'GroupDescription', 'VpcId', 'SecurityGroupEgress'}, {'SecurityGroupIngress', 'Tags'})
        c._require(group['VpcId'] == p['vpcId'], 'EXISTING_RESOURCE_MUTATION')
        c._require(not group.get('SecurityGroupIngress'), 'PUBLIC_NETWORK_DENIED')
        rules = group['SecurityGroupEgress']
        c._require(type(rules) is list and bool(rules), 'PUBLIC_NETWORK_DENIED')
        for rule in rules:
            fields(rule, {'IpProtocol', 'FromPort', 'ToPort', 'CidrIp'}, {'Description'})
            private_cidr(rule['CidrIp'])
            c._require(rule['IpProtocol'] == 'tcp' and rule['FromPort'] == 443 and rule['ToPort'] == 443, 'PUBLIC_NETWORK_DENIED')
        attachment(p['vpcId'], types[1], logical)
    for logical, machine in machines.items():
        fields(machine, {'ImageId', 'InstanceType', 'IamInstanceProfile', 'Monitoring', 'NetworkInterfaces', 'MetadataOptions', 'BlockDeviceMappings'}, {'Tags'})
        c._require(machine['ImageId'] == p['imageId'] and machine['InstanceType'] == p['instanceType'], 'LOCAL_POLICY_DENIED')
        c._require(machine['IamInstanceProfile'] == p['instanceProfile'] and machine['Monitoring'] is True, 'LOCAL_POLICY_DENIED')
        c._require(machine['MetadataOptions'] == {'HttpTokens': 'required', 'HttpEndpoint': 'enabled'}, 'LOCAL_POLICY_DENIED')
        interfaces = machine['NetworkInterfaces']
        c._require(type(interfaces) is list and len(interfaces) == 1, 'PUBLIC_NETWORK_DENIED')
        nic = interfaces[0]
        fields(nic, {'DeviceIndex', 'AssociatePublicIpAddress', 'SubnetId', 'GroupSet', 'DeleteOnTermination'})
        c._require(nic['AssociatePublicIpAddress'] is False and nic['DeviceIndex'] in ('0', 0) and
                   nic['SubnetId'] == p['subnetId'] and nic['DeleteOnTermination'] is True, 'PUBLIC_NETWORK_DENIED')
        c._require(type(nic['GroupSet']) is list and bool(nic['GroupSet']) and
                   all(g in {resource_ref(name, 'GroupId') for name in groups} for g in nic['GroupSet']), 'PUBLIC_NETWORK_DENIED')
        disks = machine['BlockDeviceMappings']
        c._require(type(disks) is list and bool(disks), 'LOCAL_POLICY_DENIED')
        for disk in disks:
            fields(disk, {'DeviceName', 'Ebs'})
            fields(disk['Ebs'], {'Encrypted', 'VolumeSize', 'VolumeType', 'DeleteOnTermination'})
            c._require(disk['Ebs']['Encrypted'] is True and disk['Ebs']['DeleteOnTermination'] is False and
                       type(disk['Ebs']['VolumeSize']) is int and 1 <= disk['Ebs']['VolumeSize'] <= 1024 and
                       disk['Ebs']['VolumeType'] in ('gp3', 'gp2'), 'LOCAL_POLICY_DENIED')
        attachment(p['subnetId'], types[0], logical)
        attachment(p['instanceProfile'], types[0], logical)
        c._require(any(a.get('Dimensions') == [{'Name': 'InstanceId', 'Value': resource_ref(logical)}] for a in alarms.values()), 'MONITORING_REQUIRED')
        arn = compose('', ['arn:aws:ec2:', p['region'], ':', p['account'], ':instance/', resource_ref(logical)])
        c._require(any(arn in b.get('BackupSelection', {}).get('Resources', []) for b in backups.values()), 'BACKUP_REQUIRED')
    for alarm in alarms.values():
        fields(alarm, {'Namespace', 'MetricName', 'Statistic', 'Period', 'EvaluationPeriods', 'Threshold',
                       'ComparisonOperator', 'TreatMissingData', 'Dimensions'}, {'AlarmDescription'})
        c._require(alarm['Namespace'] == 'AWS/EC2' and alarm['MetricName'] == 'StatusCheckFailed' and
                   alarm['Statistic'] == 'Maximum' and alarm['Threshold'] == 0 and
                   alarm['ComparisonOperator'] == 'GreaterThanThreshold' and alarm['TreatMissingData'] == 'breaching' and
                   type(alarm['Period']) is int and 10 <= alarm['Period'] <= 300 and
                   type(alarm['EvaluationPeriods']) is int and 1 <= alarm['EvaluationPeriods'] <= 5, 'MONITORING_REQUIRED')
        c._require(alarm['Dimensions'] in [[{'Name': 'InstanceId', 'Value': resource_ref(name)}] for name in machines], 'MONITORING_REQUIRED')
    for logical, backup in backups.items():
        fields(backup, {'BackupPlanId', 'BackupSelection'})
        selection = backup['BackupSelection']
        fields(selection, {'SelectionName', 'IamRoleArn', 'Resources'})
        c._require(backup['BackupPlanId'] == p['backupPlanId'] and selection['IamRoleArn'] == p['backupRoleArn'], 'BACKUP_REQUIRED')
        allowed = {compose('', ['arn:aws:ec2:', p['region'], ':', p['account'], ':instance/', resource_ref(name)]) for name in machines}
        c._require(type(selection['Resources']) is list and bool(selection['Resources']) and set(selection['Resources']) <= allowed, 'BACKUP_REQUIRED')
        attachment(p['backupPlanId'], types[3], logical)
        attachment(p['backupRoleArn'], types[3], logical)
