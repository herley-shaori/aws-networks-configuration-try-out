package com.myorg;

import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.services.ec2.*;
import software.amazon.awscdk.services.iam.ManagedPolicy;
import software.amazon.awscdk.services.iam.Role;
import software.amazon.awscdk.services.iam.ServicePrincipal;
import software.constructs.Construct;

import java.util.List;

public final class Ec2AStack extends Stack {
    private final Instance ec2A;

    public Ec2AStack(final Construct scope, final String id, final StackProps props, Vpc vpc) {
        super(scope, id, props);

        // Create Security Group for EC2
        SecurityGroup sg = SecurityGroup.Builder.create(this, "sg-ec2a")
                .vpc(vpc)
                .allowAllOutbound(true)
                .description("Security group for Ec2A instances")
                .build();

        // Allow SSH access (port 22) from anywhere (remove in production)
        sg.addIngressRule(Peer.anyIpv4(), Port.tcp(22), "Allow SSH access from anywhere");
        sg.addIngressRule(Peer.anyIpv4(), Port.icmpPing(), "Allow ICMP from anywhere");
        sg.addIngressRule(Peer.anyIpv4(), Port.udp(500), "Allow ISAKMP for IPSec");
        sg.addIngressRule(Peer.anyIpv4(), Port.udp(4500), "Allow NAT-T for IPSec");

        // Create IAM Role for EC2 with SSM permissions
        Role ec2SsmRole = Role.Builder.create(this, "Ec2SsmRole")
                .assumedBy(new ServicePrincipal("ec2.amazonaws.com"))
                .managedPolicies(List.of(
                        ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore")
                ))
                .build();

        // Define User Data script to install and configure StrongSwan
        UserData userData = UserData.forLinux();

        // Create EC2 instance in public subnet with User Data
        ec2A = Instance.Builder.create(this, "Ec2A")
                .vpc(vpc)
                .instanceType(InstanceType.of(InstanceClass.BURSTABLE3, InstanceSize.NANO)) // t3.nano
                .machineImage(MachineImage.latestAmazonLinux2023())
                .securityGroup(sg)
                .vpcSubnets(SubnetSelection.builder().subnetType(SubnetType.PUBLIC).build())
                .role(ec2SsmRole)                         // Attach the IAM role
                .userData(userData)                       // Attach the User Data script
                .build();
    }

    public String getInstancePublicIp() {
        return ec2A.getInstancePublicIp();
    }
}