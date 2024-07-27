from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.network import InternetGateway
from diagrams.custom import Custom

with Diagram("Connect to Private EC2 using a Bastion", show=False, direction="LR"):
    person = Custom("Person", "../logo/person.png")
    with Cluster("VPC"):
        igw = InternetGateway("Internet Gateway")
        with Cluster("Public Subnet") as publicsubnet:
            publicEC2 = EC2("EC2 (Bastion Host)")
        with Cluster("Private Subnet"):
            privateEC2 = EC2("EC2")
    person >> igw
    igw << Edge(dir="both") >> publicEC2
    publicEC2 >> privateEC2