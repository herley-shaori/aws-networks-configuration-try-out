package com.myorg;

import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.Tags;
import software.amazon.awscdk.services.ec2.*;
import software.constructs.Construct;

public final class VpnAStack extends Stack {
    private final CfnCustomerGateway customerGateway;
//    private final CfnVPNGateway vpnGateway;

    public VpnAStack(final Construct scope, final String id, final StackProps props, String ec2APublicIp, Vpc vpcA, Vpc vpcB) {
        super(scope, id, props);

        // Create the Customer Gateway using the imported public IP
        this.customerGateway = CfnCustomerGateway.Builder.create(this, "CustomerGateway")
                .ipAddress(ec2APublicIp)
                .type("ipsec.1")
                .bgpAsn(65000)
                .build();
        Tags.of(customerGateway).add("Name", "CustomerGatewayA");

        // Create the VPN Gateway
//        this.vpnGateway = CfnVPNGateway.Builder.create(this, "VgwA")
//                .type("ipsec.1")
//                .build();
//
//        Tags.of(vpnGateway).add("Name", "VpnGatewayA");
//
//        // Attach the VPN Gateway to the VPC
//        CfnVPCGatewayAttachment vpcAttachment = CfnVPCGatewayAttachment.Builder.create(this, "VpcAAttachment")
//                .vpcId(vpcA.getVpcId())
//                .vpnGatewayId(vpnGateway.getRef())
//                .build();
//
//        // Tambahkan dependensi eksplisit agar route menunggu attachment selesai
//        vpcAttachment.addDependency(vpnGateway);
    }

    public String getCustomerGatewayId() {
        return customerGateway.getAttrCustomerGatewayId();
    }

//    public String getVpnGatewayId() {
//        return vpnGateway.getAttrVpnGatewayId();
//    }
}