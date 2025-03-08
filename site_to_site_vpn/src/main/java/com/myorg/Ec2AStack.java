package com.myorg;

import software.amazon.awscdk.Stack;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.services.ec2.*;
import software.amazon.awscdk.services.iam.ManagedPolicy;
import software.amazon.awscdk.services.iam.Role;
import software.amazon.awscdk.services.iam.ServicePrincipal;
import software.constructs.Construct;

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

        // Create IAM Role for EC2 with SSM permissions
        Role ec2SsmRole = Role.Builder.create(this, "Ec2SsmRole")
                .assumedBy(new ServicePrincipal("ec2.amazonaws.com"))
                .managedPolicies(java.util.Arrays.asList(
                        ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore")
                ))
                .build();

        // Define User Data script to install and configure StrongSwan
        UserData userData = UserData.forLinux();
        userData.addCommands(
                "#!/bin/bash",
                "yum update -y",                           // Update package manager
                "yum install strongswan -y",              // Install StrongSwan

                // Enable IP forwarding
                "sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf",
                "sysctl -p",

                // Get the public IP of the instance
                "PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)",

                // Configure ipsec.conf for both tunnels
                "cat > /etc/strongswan/ipsec.conf << 'EOF'",
                "config setup",
                "  charondebug=\"ike 2, knl 2, cfg 2\"",
                "  uniqueids=no",
                "",
                "conn %default",
                "  ikelifetime=28800s",
                "  keylife=3600s",
                "  rekeymargin=3m",
                "  keyingtries=%forever",
                "  keyexchange=ikev1",
                "  authby=secret",
                "  dpddelay=10s",
                "  dpdtimeout=30s",
                "  dpdaction=restart",
                "",
                "conn aws-tunnel1",
                "  left=%any",
                "  leftid=$PUBLIC_IP",
                "  leftsubnet=10.0.0.0/16",              // VPC A CIDR
                "  right=16.78.37.31",                   // Tunnel 1 Outside IP
                "  rightsubnet=172.16.0.0/16",          // VPC B CIDR
                "  type=tunnel",
                "  auto=start",
                "  ike=aes128-sha1-modp1024",
                "  esp=aes128-sha1",
                "  mark=100",
                "",
                "conn aws-tunnel2",
                "  left=%any",
                "  leftid=$PUBLIC_IP",
                "  leftsubnet=10.0.0.0/16",              // VPC A CIDR
                "  right=16.78.205.31",                  // Tunnel 2 Outside IP
                "  rightsubnet=172.16.0.0/16",          // VPC B CIDR
                "  type=tunnel",
                "  auto=start",
                "  ike=aes128-sha1-modp1024",
                "  esp=aes128-sha1",
                "  mark=200",
                "EOF",

                // Configure ipsec.secrets with actual PSK
                "cat > /etc/strongswan/ipsec.secrets << 'EOF'",
                "$PUBLIC_IP 16.78.37.31 : PSK \"_ZyzcQ94lxQI847r5IUfJbS98oMmtWxF\"",  // Tunnel 1 PSK
                "$PUBLIC_IP 16.78.205.31 : PSK \"UH9wCPeGHG_rQNFNvTzaM2TrcK8djtoT\"",  // Tunnel 2 PSK
                "EOF",

                // Start StrongSwan service
                "systemctl enable strongswan",
                "systemctl start strongswan"
        );

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