// Local example only. parameters.json contains explicit owner-supplied references.
const cdk = require('aws-cdk-lib');
const p = require('./parameters.json');
const app = new cdk.App();
const stack = new cdk.Stack(app, 'Private', {
  stackName: p.stackName, env: { account: p.account, region: p.region },
  synthesizer: new cdk.DefaultStackSynthesizer({ generateBootstrapVersionRule: false }),
});
const group = new cdk.aws_ec2.CfnSecurityGroup(stack, 'PrivateGroup', {
  groupDescription: 'Private workload; private management endpoints required',
  vpcId: p.vpcId, securityGroupIngress: [],
  securityGroupEgress: [{ ipProtocol: 'tcp', fromPort: 443, toPort: 443, cidrIp: '10.0.0.0/16' }],
});
const image = new cdk.CfnParameter(stack, 'Image', { type: 'AWS::EC2::Image::Id', default: p.imageId });
const machine = new cdk.aws_ec2.CfnInstance(stack, 'Workload', {
  imageId: image.valueAsString, instanceType: p.instanceType, iamInstanceProfile: p.instanceProfile,
  monitoring: true, metadataOptions: { httpTokens: 'required', httpEndpoint: 'enabled' },
  networkInterfaces: [{ deviceIndex: '0', associatePublicIpAddress: false,
    subnetId: p.subnetId, groupSet: [group.attrGroupId], deleteOnTermination: true }],
  blockDeviceMappings: [{ deviceName: '/dev/xvda', ebs: { encrypted: true, volumeSize: 16, volumeType: 'gp3', deleteOnTermination: false } }],
});
// Exact owner image is required here; no mutable lookup is allowed.
cdk.Validations.of(machine).acknowledge({ id: 'CloudFormation-Validate::W9010', reason: 'Exact image is bound in the immutable request.' });
new cdk.aws_cloudwatch.CfnAlarm(stack, 'Health', {
  namespace: 'AWS/EC2', metricName: 'StatusCheckFailed', statistic: 'Maximum',
  period: 60, evaluationPeriods: 2, threshold: 0,
  comparisonOperator: 'GreaterThanThreshold', treatMissingData: 'breaching',
  dimensions: [{ name: 'InstanceId', value: machine.ref }],
});
new cdk.aws_backup.CfnBackupSelection(stack, 'Protection', {
  backupPlanId: p.backupPlanId,
  backupSelection: { selectionName: 'private-workload', iamRoleArn: p.backupRoleArn,
    resources: [stack.formatArn({ service: 'ec2', resource: 'instance', resourceName: machine.ref })] },
});
app.synth();
