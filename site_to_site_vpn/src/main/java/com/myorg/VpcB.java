package com.myorg;

import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.Tags;
import software.amazon.awscdk.services.ec2.IpAddresses;
import software.amazon.awscdk.services.ec2.SubnetConfiguration;
import software.amazon.awscdk.services.ec2.SubnetType;
import software.amazon.awscdk.services.ec2.Vpc;
import software.constructs.Construct;
import java.util.List;

public final class VpcB extends Stack {
    private final Vpc vpc;
    private final SubnetConfiguration privateSubnet;

    public VpcB(final Construct scope, final String id, final StackProps props) {
        super(scope, id, props);

        // Define subnet configuration for the private subnet
        privateSubnet = SubnetConfiguration.builder()
                .name("PrivateSubnet")
                .subnetType(SubnetType.PRIVATE_ISOLATED)
                .cidrMask(27)
                .build();

        // Create the VPC
        this.vpc = Vpc.Builder.create(this, "VpcB")
                .ipAddresses(IpAddresses.cidr("10.0.0.0/26"))
                .maxAzs(1)
                .subnetConfiguration(List.of(privateSubnet))
                .build();

        // Add tags to the private subnet
        this.vpc.getIsolatedSubnets().forEach(subnet -> Tags.of(subnet).add("Name", "vpc-B-PrivateSubnet"));
    }

    public Vpc getVpc() {
        return vpc;
    }
    public SubnetConfiguration getPrivateSubnet() {
        return privateSubnet;
    }
}