package com.myorg;

import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.Tags;
import software.amazon.awscdk.services.ec2.*;
import software.constructs.Construct;

public final class VpnBStack extends Stack {
    private final CfnVPNGateway vpnGateway;
    private final CfnCustomerGateway customerGateway;
    public VpnBStack(final Construct scope, final String id, final StackProps props, Vpc vpcb, Vpc vpca, String ec2APublicIp) {
        super(scope, id, props);
        // Create the VPN Gateway
        this.vpnGateway = CfnVPNGateway.Builder.create(this, "VgwB")
                .type("ipsec.1")
                .build();

        // Attach the VPN Gateway to the VPC
        CfnVPCGatewayAttachment.Builder.create(this, "VpcBAttachment")
                .vpcId(vpcb.getVpcId())
                .vpnGatewayId(vpnGateway.getRef())
                .build();

        Tags.of(vpnGateway).add("Name", "VpnGatewayB");

        this.customerGateway = CfnCustomerGateway.Builder.create(this, "CustomerGateway")
                .ipAddress(ec2APublicIp)
                .type("ipsec.1")
                .bgpAsn(65000)
                .build();
        Tags.of(customerGateway).add("Name", "CustomerGatewayA");

        // Now you can use vpnGatewayId when creating the VPN Connection and routes
        CfnVPNConnection vpnConnection = CfnVPNConnection.Builder.create(this, "VpnConnectionB")
                .customerGatewayId(this.customerGateway.getAttrCustomerGatewayId()) // from VpnAStack.
                .vpnGatewayId(this.vpnGateway.getAttrVpnGatewayId())           // from VpcB.
                .type("ipsec.1")
                .staticRoutesOnly(true)               // Static routing karena tidak ada BGP.
                .localIpv4NetworkCidr(vpca.getVpcCidrBlock())
                .remoteIpv4NetworkCidr(vpcb.getVpcCidrBlock())
                .build();

        Tags.of(vpnConnection).add("Name", "VpnConnection");

        // Add route to VPC A's CIDR via VPN Gateway in VPC B's private subnet route table
        int[] index = {0};
        vpcb.getIsolatedSubnets().forEach(subnet -> {
            System.out.println("Adding route to subnet: " + subnet.getSubnetId() + ", RouteTable: " + subnet.getRouteTable().getRouteTableId());
            CfnRoute route = CfnRoute.Builder.create(this, "RouteToVpcA-" + index[0]++)
                    .routeTableId(subnet.getRouteTable().getRouteTableId())
                    .destinationCidrBlock(vpca.getVpcCidrBlock())
                    .gatewayId(this.vpnGateway.getAttrVpnGatewayId())
                    .build();
            route.addDependency(vpnGateway); // Ensure VPN Gateway is ready
        });

        // Tambahkan rute statis untuk VPC A
        CfnVPNConnectionRoute vpnRouteToVpcA = CfnVPNConnectionRoute.Builder.create(this, "VpnRouteToVpcA")
                .destinationCidrBlock(vpca.getVpcCidrBlock()) // CIDR VPC A
                .vpnConnectionId(vpnConnection.getRef())
                .build();
    }
}