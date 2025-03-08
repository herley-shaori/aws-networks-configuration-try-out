package com.myorg;

import software.amazon.awscdk.services.ec2.*;
import software.amazon.awscdk.services.iam.*;
import software.constructs.Construct;
import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;

public final class Ec2BStack extends Stack {

    public Ec2BStack(final Construct scope, final String id, final StackProps props, Vpc vpc) {
        super(scope, id, props);

        // Create Security Group for EC2 in VPC B
        SecurityGroup sg = SecurityGroup.Builder.create(this, "sg-ec2b")
                .vpc(vpc)
                .allowAllOutbound(true)
                .description("Security group for Ec2B instances")
                .build();

        // Allow ICMP (ping) and SSH from VPC A's CIDR
        sg.addIngressRule(Peer.ipv4("10.0.0.0/16"), Port.icmpPing(), "Allow ICMP from VPC A");
        sg.addIngressRule(Peer.ipv4("10.0.0.0/16"), Port.tcp(22), "Allow SSH from VPC A");

        // Create IAM Role for EC2 with SSM permissions
        Role ec2SsmRole = Role.Builder.create(this, "Ec2SsmRole")
                .assumedBy(new ServicePrincipal("ec2.amazonaws.com"))
                .managedPolicies(java.util.Arrays.asList(
                        ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore")
                ))
                .build();

        // Create EC2 instance in private subnet
        Instance ec2B = Instance.Builder.create(this, "Ec2B")
                .vpc(vpc)
                .instanceType(InstanceType.of(InstanceClass.BURSTABLE3, InstanceSize.NANO)) // t3.nano
                .machineImage(MachineImage.latestAmazonLinux2023())
                .securityGroup(sg)
                .vpcSubnets(SubnetSelection.builder().subnetType(SubnetType.PRIVATE_ISOLATED).build())
                .role(ec2SsmRole) // Attach the IAM role
                .build();
    }
}