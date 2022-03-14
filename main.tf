


#Project_show_your_skills_interview
#Sources

#IPv4 Subnet Creator
#https://network00.com/NetworkTools/IPv4SubnetCreator/

#Freecodecamp
#Terraform Course - Automate your AWS cloud infrastructure - https://www.youtube.com/watch?v=SLB_c_ayRMo&t=3073s&ab_channel=freeCodeCamp.org

#DevOps Directive
#Complete Terraform Course - From BEGINNER to PRO! (Learn Infrastructure as Code) - https://www.youtube.com/watch?v=7xngnjfIlK4&ab_channel=DevOpsDirective

#Terraform registry - providers AWS
#Multiple sub-websites
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs


#1 - Choosing a cloud provider and a region
provider "aws" {
  region = "us-east-1"
}
#2 - Creating a custom VPC
resource "aws_vpc" "project_vpc" {
  cidr_block ="20.0.0.0/16"
  tags = {
    Name ="Show_your_skills_VPC"
    }
}
#3 - Creating a custom Internet Gateway - being able to assing a public IP
resource "aws_internet_gateway" "project_gw" {
  vpc_id = aws_vpc.project_vpc.id
  tags = {
    Name = "project_terraform"
  }
}
#4 - Creating a custom Route Table to determine where network traffic is directed
resource "aws_route_table" "project_route_table" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project_gw.id
  }
}
#5 - Creating a custom subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.project_vpc.id
  cidr_block = "20.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subnet-1"
  }
}
#6 - Creating a 2nd custom subnet
resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.project_vpc.id
  cidr_block = "20.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "subnet-2"
  }
}
#7 - Creating a route table association to cause traffic
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.project_route_table.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.project_route_table.id
}
#8 - Creating a AWS Security Group to determine what kind of traffic is allowed
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.project_vpc.id

  ingress {
    description      = "https from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

ingress {
    description      = "http from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  ingress {
    description      = "ssh from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
#9 - Creating a Network interfaces and assigning them elastic IPs
resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["20.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}
resource "aws_network_interface" "web_server_nic_2" {
  subnet_id       = aws_subnet.subnet-2.id
  private_ips     = ["20.0.2.50"]
  security_groups = [aws_security_group.allow_web.id]

}
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "20.0.1.50"
  depends_on = [aws_internet_gateway.project_gw]
}
#10 - Instances creation(two availability zones) + adding user data in bash
resource "aws_instance" "web_server_instance_1"{
  ami = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo <h1>this is my 1st web server deployed in us-east-1a by terraform</h2> > /var/www/html/index.html'
              EOF

  tags = {
    Name ="web_server_1"
  }
}
resource "aws_eip" "two" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic_2.id
  associate_with_private_ip = "20.0.2.50"
  depends_on = [aws_internet_gateway.project_gw]
}
resource "aws_instance" "web_server_instance_2"{
  ami = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  availability_zone = "us-east-1b"
  key_name = "main-key"
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web_server_nic_2.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo <h1>this is my 2nd web server deployed in us-east-1b by terraform</h1> > /var/www/html/index.html'
              EOF

  tags = {
    Name ="web_server_2"
  }
}
#11 - Creating a Elastic Load Balancer to distribute incoming traffic across multiple EC2 instances in multiple AZs.
resource "aws_elb" "skills-elb" {
    name = "skills-elb"
    subnets = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
    security_groups = [aws_security_group.allow_web.id]
    
    listener {
        instance_port     = 80
        instance_protocol = "http"
        lb_port           = 80
        lb_protocol       = "http"
    }
    


    health_check {
        healthy_threshold   = 10
        unhealthy_threshold = 2
        timeout             = 3
        target              = "HTTP:80/"
        interval            = 30
    }
              
    instances                   = [aws_instance.web_server_instance_1.id, aws_instance.web_server_instance_2.id]
    cross_zone_load_balancing   = true
    idle_timeout                = 400
    connection_draining         = true
    connection_draining_timeout = 400

    tags = {
        Name = "skills-elb"
    }
}

#"printing out" the dns of ELB(to check if our stack works) and the public IP's for both servers to SSH to them.

  
 output "server_public_ip" {
    value = aws_instance.web_server_instance_1.public_ip
  }
  output "server_public_ip_2" {
    value = aws_instance.web_server_instance_2.public_ip
  }
output "Load_Balancer_DNS" {
    value = aws_elb.skills-elb.dns_name
  }
  

