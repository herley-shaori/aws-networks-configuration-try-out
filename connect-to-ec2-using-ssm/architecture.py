from diagrams import Diagram,Cluster,Edge
from diagrams.aws.compute import EC2
from diagrams.custom import Custom

graph_attr = {
    "bgcolor": "transparent"
}

with Diagram('Failed Connection', show=False, direction='LR'):
    orang = Custom('Person','../logo/Person.png')
    with Cluster('VPC') as vpc:
        with Cluster('Private Subnet'):
            ec2 = EC2('EC2')
    orang >> Edge(label='connection failed',color='Red') >> ec2

with Diagram('Succesful Connection', show=False, direction='LR'):
    with Cluster('VPC') as vpc:
        orang = Custom('Person', '../logo/Person.png')
        with Cluster('Private Subnet'):
            ec2 = EC2('EC2')
    orang >> Edge(label='connection succes') >> ec2
