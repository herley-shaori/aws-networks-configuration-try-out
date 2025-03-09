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

public final class VpcA extends Stack {

    private final Vpc vpc;

    public VpcA(final Construct scope, final String id, final StackProps props) {
        super(scope, id, props);

        // Define subnet configuration for the public subnet
        SubnetConfiguration publicSubnet = SubnetConfiguration.builder()
                .name("PublicSubnet")
                .subnetType(SubnetType.PUBLIC)
                .cidrMask(27)
                .build();

        // Create the VPC with CIDR 192.168.0.0/26
        this.vpc = Vpc.Builder.create(this, "VpcA")
                .ipAddresses(IpAddresses.cidr("192.168.0.0/26"))
                .maxAzs(1)
                .subnetConfiguration(List.of(publicSubnet))
                .build();

        // Add tags to the subnets
        this.vpc.getPublicSubnets().forEach(subnet -> Tags.of(subnet).add("Name", "vpc-A-PublicSubnet"));
    }

    public Vpc getVpc() {
        return vpc;
    }
}