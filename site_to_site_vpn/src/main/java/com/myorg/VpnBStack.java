package com.myorg;

import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.Tags;
import software.amazon.awscdk.services.ec2.*;
import software.constructs.Construct;

public final class VpnBStack extends Stack {
    private final CfnVPNGateway vpnGateway;
    public VpnBStack(final Construct scope, final String id, final StackProps props, Vpc vpc, String customerGatewayId) {
        super(scope, id, props);
        // Create the VPN Gateway
        this.vpnGateway = CfnVPNGateway.Builder.create(this, "VgwB")
                .type("ipsec.1")
                .build();

        // Attach the VPN Gateway to the VPC
        CfnVPCGatewayAttachment.Builder.create(this, "VpcBAttachment")
                .vpcId(vpc.getVpcId())
                .vpnGatewayId(vpnGateway.getRef())
                .build();

        Tags.of(vpnGateway).add("Name", "VpnGatewayB");

        // Now you can use vpnGatewayId when creating the VPN Connection and routes
        CfnVPNConnection vpnConnection = CfnVPNConnection.Builder.create(this, "VpnConnectionB")
                .customerGatewayId(customerGatewayId) // from VpnAStack.
                .vpnGatewayId(this.vpnGateway.getAttrVpnGatewayId())           // from VpcB.
                .type("ipsec.1")
                .staticRoutesOnly(true)               // Static routing karena tidak ada BGP.
                .build();

        // Add route to VPC A's CIDR via VPN Gateway in VPC B's private subnet route table
        vpc.getPrivateSubnets().forEach(subnet -> {
            CfnRoute.Builder.create(this, "RouteToVpcA")
                    .routeTableId(subnet.getRouteTable().getRouteTableId())
                    .destinationCidrBlock("10.0.0.0/16") // CIDR VPC A
                    .gatewayId(this.vpnGateway.getAttrVpnGatewayId())
                    .build();
        });
    }
}