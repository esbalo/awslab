
variable ec2 {
  type    = list
  default = ["swarm", "kubernetes"]
}
resource "aws_vpc" "lab_vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "lab"
  }
}

resource "aws_subnet" "lab_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "172.16.10.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab"
  }
}

resource "aws_internet_gateway" "lab_ig" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "terraform-eks-demo"
  }
}

resource "aws_route_table" "lab_route" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_ig.id
  }
}

resource "aws_route_table_association" "lab_route_assoc" {
  subnet_id      = aws_subnet.lab_subnet.id
  route_table_id = aws_route_table.lab_route.id
}

resource "aws_network_interface" "lab_nic" {
  count       = length(var.ec2)
  subnet_id   = aws_subnet.lab_subnet.id
  private_ips = [cidrhost("172.16.10.0/24", 100 + count.index)]

  tags = {
    Name = "primary_network_interface of ${var.ec2[count.index]}"
  }
}

resource "aws_security_group_rule" "eks_ebl_ingress_node_ssh" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow workstation connect by SSH"
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_vpc.lab_vpc.default_security_group_id
  to_port           = 22
  type              = "ingress"
}

# resource "aws_security_group" "lab_sg" {
#   name        = "lab_sg"
#   description = "Security group for lab"
#   vpc_id      = aws_vpc.lab_vpc.id

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   ingress {
#     description = "SSH from internet"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     "Name"                                      = "lab_sg"
#   }
# }

resource "aws_key_pair" "ebl_key" {
  key_name   = "ebl-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDbDTfqYwUi9QANFQop9ARSzO3+OFCdjOvEk7p7eJxhfDXmchQhCcoZUT1y+32zcY1IFRjtejs80eEu/0cbkyzlPF1Y1hJNZnEmQDinJQ/CoE6wFriEjo73ZP6FlQgpCo2zVE0vhTAm8npnR1fMKkFoPMpPVrXpytaGhdgJjBkGc5N6kuJdcXDM6p8mwrEiBI7Pz/A7cLmDNxaxrj2LQA3dcGQaiq8/QRIpUw1xlyMzXQCEOmcnkA/jqFpkcaCyOFfpZaDnAt3bO8zXwstHSXtjxvt0JJmGnMl4rVSJdLT8U64hWusdD+FrvWRefsjUb0LM4JQAy8gcHu73tiwVtQID administrator@LTKB062"
}

resource "aws_instance" "vm" {
  count         = length(var.ec2)
  ami           = "ami-9befb4fe"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ebl_key.key_name

  network_interface {
    network_interface_id = aws_network_interface.lab_nic[count.index].id
    device_index         = 0
  }

  tags = {
    Name = var.ec2[count.index]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }
}