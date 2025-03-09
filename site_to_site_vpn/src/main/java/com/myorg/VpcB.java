package com.myorg;

import software.amazon.awscdk.Tags;
import software.constructs.Construct;
import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.services.ec2.*;

import java.util.List;

public final class VpcB extends Stack {
    private final Vpc vpc;

    public VpcB(final Construct scope, final String id, final StackProps props) {
        super(scope, id, props);

        // Define subnet configuration for the private subnet
        SubnetConfiguration privateSubnet = SubnetConfiguration.builder()
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

        // Create VPC Endpoints for SSM
//        vpc.addInterfaceEndpoint("SsmVpcEndpoint", InterfaceVpcEndpointOptions.builder()
//                .service(InterfaceVpcEndpointAwsService.SSM)
//                .privateDnsEnabled(true)
//                .build());
//
//        vpc.addInterfaceEndpoint("SsmMessagesVpcEndpoint", InterfaceVpcEndpointOptions.builder()
//                .service(InterfaceVpcEndpointAwsService.SSM_MESSAGES)
//                .privateDnsEnabled(true)
//                .build());
//
//        vpc.addInterfaceEndpoint("Ec2MessagesVpcEndpoint", InterfaceVpcEndpointOptions.builder()
//                .service(InterfaceVpcEndpointAwsService.EC2_MESSAGES)
//                .privateDnsEnabled(true)
//                .build());
//
//        vpc.addInterfaceEndpoint("StsVpcEndpoint", InterfaceVpcEndpointOptions.builder()
//                .service(InterfaceVpcEndpointAwsService.STS)
//                .privateDnsEnabled(true)
//                .build());
    }

    public Vpc getVpc() {
        return vpc;
    }
}