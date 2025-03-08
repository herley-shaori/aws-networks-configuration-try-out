package com.myorg;

import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
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

        // Define subnet configuration for the private subnet
        SubnetConfiguration privateSubnet = SubnetConfiguration.builder()
                .name("PrivateSubnet")
                .subnetType(SubnetType.PRIVATE_ISOLATED)
                .cidrMask(24)
                .build();

        // Define subnet configuration for the public subnet (untuk EC2)
        SubnetConfiguration publicSubnet = SubnetConfiguration.builder()
                .name("PublicSubnet")
                .subnetType(SubnetType.PUBLIC)
                .cidrMask(24)
                .build();

        // Create the VPC with CIDR 10.0.0.0/16
        this.vpc = Vpc.Builder.create(this, "VpcA")
                .ipAddresses(IpAddresses.cidr("10.0.0.0/16"))
                .maxAzs(3)  // Use up to 3 availability zones
                .subnetConfiguration(List.of(publicSubnet, privateSubnet)) // Tambahkan public subnet
                .build();
    }

    public Vpc getVpc() {
        return vpc;
    }
}