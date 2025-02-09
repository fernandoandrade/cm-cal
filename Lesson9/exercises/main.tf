provider "aws" {
  region                  = "us-east-1"
  access_key              = "ASIAUMD25XDLPKISRL3W"
  secret_key              = "QQa/qXDvaJFtsSsMC7FEI5fapxQgqJAW7Wc1E2UP"
  token                   = "FwoGZXIvYXdzEFkaDEZLJnuA7ee9mvlgPyK1Adm2m9BWm96zXyIA+qRq2tU50i8HMhywBsC1qQlyTGNudne9XOWIsVyIPlzTJz7ULb+WbLi2mYRSgKagtYJBpMzH6Z5cJuJwQfZq0lpcgmsFLYIJXlabyGlkkrIKhheRP3ROcxC10qE/nUn2a0k52+Ci5zyywLISVzsDN/Cbh45OqBPbxquM9VFAQWu+6TmICP42VpV0xNe1xScwnrJ2NmIeKxG8/Qi5fF9Zx5d9BhnCWJ+tSGQomNrOigYyLaNRp7TENfprFuI2x1JCp2gQbKbDNoB4SE4C/DZx2LrXm71NN2JWi3cFENx3wQ=="
}

resource "tls_private_key" "private-key" {
  algorithm   = "RSA"
  rsa_bits    = 2048
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.private-key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "student-sg" {
  name = "Hello-World-SG"
  description = "Student security group"

  tags = {
    Name = "Hello-World-SG"
    Environment = terraform.workspace
  }
}

resource "aws_security_group_rule" "create-sgr-ssh" {
  security_group_id = aws_security_group.student-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  protocol          = "tcp"
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "create-sgr-inbound" {
  security_group_id = aws_security_group.student-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "ingress"
}

resource "aws_security_group_rule" "create-sgr-outbound" {
  security_group_id = aws_security_group.student-sg.id
  cidr_blocks         = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  to_port           = 65535
  type              = "egress"
}

resource "aws_instance" "web" {
  count         = 3 
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = ["Hello-World-SG"]
  tags = {
    Name = "Web${count.index}"
  }
}

resource "null_resource" "control-node" {
    depends_on = [aws_instance.web]
  
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.private-key.private_key_pem
      host        = aws_instance.web.*.public_dns[0]
    }

    provisioner "remote-exec" {
      inline = [
        "sudo apt update -y",
        "sudo apt install ansible -y",
        "echo '[webservers]' > ~/hosts",
        "echo '${aws_instance.web.*.public_dns[1]}' >> ~/hosts",
        "echo '${aws_instance.web.*.public_dns[2]}' >> ~/hosts",
        "echo '${tls_private_key.private-key.private_key_pem}' > ~/.ssh/student.pem && chmod 600 ~/.ssh/student.pem",
        "sudo sed -i '71s/.*/host_key_checking = False/' /etc/ansible/ansible.cfg"
      ]
    }

    provisioner "local-exec" {
      command = "echo '${tls_private_key.private-key.private_key_pem}' > ~/.ssh/student.pem && chmod 600 ~/.ssh/student.pem "
    }
}
