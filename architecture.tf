provider "aws" {
  region = "us-east-1"
}

# resource "aws_iam_role" "role" {
#   name = "role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

resource "aws_security_group" "set_the_ports" {
  name_prefix = "set_the_ports"
  vpc_id      = "vpc-007983d27896708f3"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2_instance" {
  ami                         = "ami-00c39f71452c08778"
  instance_type               = "t2.micro"
  vpc_security_group_ids     = [aws_security_group.set_the_ports.id]
  key_name                    = "Second_try"
  associate_public_ip_address = true

  # iam_instance_profile = "${aws_iam_instance_profile.profile.name}"
  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install docker -y
    sudo usermod -a -G docker ec2-user
    id ec2-user
    newgrp docker
    sudo systemctl start docker
    sudo systemctl enable docker
    docker pull luiciudin/devops-labs-backend:5
    docker pull luiciudin/project
    docker run -d -p 5000:5000 --name flask_application luiciudin/devops-labs-backend:5
    docker run -d -p 80:80 --name nginx luiciudin/project
    EOF
}

resource "aws_instance" "ec2_instance2" {
  ami                         = "ami-00c39f71452c08778"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.set_the_ports.id]
  key_name                    = "Second_try"
  associate_public_ip_address = true
  # iam_instance_profile = "${aws_iam_instance_profile.profile.name}"
  user_data = <<EOF
    #cloud-config
    packages:
      - apache2
    runcmd:
      - systemctl start apache2
      - systemctl enable apache2
  EOF
}

# resource "aws_iam_instance_profile" "profile" {
#   name = "profile"
#   role = "${aws_iam_role.role.name}"
# }

# resource "aws_s3_bucket_object" "html_files" {
#   bucket = "nginxhtmlfiles"
#   key    = "index_new.html"
#   source = "nginx:/usr/share/nginx/html/index.html"
# }

resource "aws_lb" "loadBalancer" {
  name               = "loadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.set_the_ports.id]
  subnets            = ["subnet-0f37b41bc055ea4c1", "subnet-069047187f4cdd06d", "subnet-06947f02c67e330e0", "subnet-0986f452d9f97ddbf", "subnet-0d32fe648cafeb81e", "subnet-05bd816db9d7b484b"]
}

resource "aws_lb_target_group" "targetGroupLb" {
  name     = "targetGroupLb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-007983d27896708f3"
  target_type      = "instance"

   health_check {
    enabled = true
    path    = "/"
    protocol = "HTTP"
    interval = 30
    timeout = 5
    healthy_threshold = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "listener_lb" {
  load_balancer_arn = aws_lb.loadBalancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.targetGroupLb.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "target_group_instance" {
  target_group_arn = aws_lb_target_group.targetGroupLb.arn
  target_id        = aws_instance.ec2_instance.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "target_group_instance2" {
  target_group_arn = aws_lb_target_group.targetGroupLb.arn
  target_id        = aws_instance.ec2_instance2.id
  port             = 80
}
