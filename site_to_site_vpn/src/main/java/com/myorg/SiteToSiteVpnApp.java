package com.myorg;

import software.amazon.awscdk.App;
import software.amazon.awscdk.Environment;
import software.amazon.awscdk.StackProps;

public class SiteToSiteVpnApp {
    public static void main(final String[] args) {
        App app = new App();

        VpcA vpcA = new VpcA(app, "vpcA", StackProps.builder()
                .description("VPC A for the Site-to-Site VPN setup")
                .env(Environment.builder()
                        .account(System.getenv("CDK_DEFAULT_ACCOUNT"))
                        .region("ap-southeast-3")
                        .build())
                .build());

        VpcB vpcB = new VpcB(app, "vpcB", StackProps.builder()
                .description("VPC B for the Site-to-Site VPN setup")
                .env(Environment.builder()
                        .account(System.getenv("CDK_DEFAULT_ACCOUNT"))
                        .region("ap-southeast-3")
                        .build())
                .build());

        Ec2AStack ec2AStack = new Ec2AStack(app, "Ec2AStack", StackProps.builder()
                .description("EC2 A Stack")
                .env(Environment.builder()
                        .account(System.getenv("CDK_DEFAULT_ACCOUNT"))
                        .region("ap-southeast-3")
                        .build())
                .build(), vpcA.getVpc());
        ec2AStack.addDependency(vpcA);

        Ec2BStack ec2BStack = new Ec2BStack(app, "Ec2BStack", StackProps.builder()
                .description("EC2 B Stack")
                .env(Environment.builder()
                        .account(System.getenv("CDK_DEFAULT_ACCOUNT"))
                        .region("ap-southeast-3")
                        .build())
                .build(), vpcB.getVpc(), vpcA.getVpc());
        ec2BStack.addDependency(vpcB);

        VpnBStack vpnBStack = new VpnBStack(app, "VpnBStack", StackProps.builder()
                .description("VPN B Stack.")
                .env(Environment.builder()
                        .account(System.getenv("CDK_DEFAULT_ACCOUNT"))
                        .region("ap-southeast-3")
                        .build())
                .build(), vpcB.getVpc(), vpcA.getVpc(), ec2AStack.getInstancePublicIp());
        vpnBStack.addDependency(ec2AStack);

        app.synth();
    }
}