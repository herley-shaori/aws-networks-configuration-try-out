from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.network import VPC,VPCPeering, PrivateSubnet, PublicSubnet,RouteTable, InternetGateway,Endpoint
from diagrams.aws.management import SystemsManagerParameterStore
from diagrams.aws.security import IAMRole
from diagrams.aws.general import User
from diagrams.onprem.iac import Terraform

with Diagram("VPC Peering", show=False, direction="LR"):
    with Cluster('AWS'):
        vpcPeering = VPC("VPC Peering")
        person = User("Person")
        with Cluster('VPC A'):
            vpcA = VPC('VPC-A')
            with Cluster('Private Subnet A'):
                ec2A = EC2('EC2 A')
        with Cluster('VPC B'):
            vpcB = VPC('VPC-B')
            with Cluster('Private Subnet B'):
                ec2B = EC2('EC2 B')
        vpcA << vpcPeering >> vpcB
        person >> Edge(label='SSM') >> ec2A