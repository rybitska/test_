# create AWS ECR repo
resource "aws_ecr_repository" "ethereum" {
  name                 = "ethereum"
  force_delete         = true


  image_scanning_configuration {
    scan_on_push = true
  }
}

# create AWS ECR policy
resource "aws_ecr_lifecycle_policy" "default_policy" {
  repository = aws_ecr_repository.ethereum.name

  policy = <<EOF
	{
	    "rules": [
	        {
	            "rulePriority": 1,
	            "description": "Keep only the last ${var.untagged_images} untagged images.",
	            "selection": {
	                "tagStatus": "untagged",
	                "countType": "imageCountMoreThan",
	                "countNumber": ${var.untagged_images}
	            },
	            "action": {
	                "type": "expire"
	            }
	        }
	    ]
	}
	EOF


}

# create AWS IAM 
resource "aws_iam_user" "admin" {
  name = "admin"
  path = "/system/"

  tags = {
    tag-key = "tag-value"
  }
}


resource "aws_iam_role" "access-to-ec2-ecr-role" {
  name               = "access-to-ec2-ecr-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# create policy to attach to the role
resource "aws_iam_policy" "access-to-ec2-ecr-policy" {
  name = "access-to-ec2-ecr-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# attach policy
resource "aws_iam_policy_attachment" "attach" {
  name       = "ecr-attach"
  roles      = [aws_iam_role.access-to-ec2-ecr-role.name] 
  policy_arn = aws_iam_policy.access-to-ec2-ecr-policy.arn
}

data "aws_caller_identity" "current" {}


resource "null_resource" "docker_packaging" {

  provisioner "local-exec" {
    command = <<EOF
	      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com
        docker pull ethereum/client-go:stable
        imageID=`docker images -q ethereum/client-go:stable`
        docker push ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/${aws_ecr_repository.ethereum.name}
	    EOF
  }


  triggers = {
    "run_at" = timestamp()
  }


  depends_on = [
    aws_ecr_repository.ethereum,
  ]
}

resource "aws_iam_instance_profile" "profile-for-ec2" {
  name = "profile-for-ec2"
  role = aws_iam_role.access-to-ec2-ecr-role.name
}

resource "aws_instance" "geth" {
  ami           = "ami-076cbd561ae9c19e9"
  instance_type = "t3.xlarge"
  iam_instance_profile = aws_iam_instance_profile.profile-for-ec2.name
  
  key_name = "" # provide key_name
  user_data =  <<-EOF
              #!/bin/bash

              sudo yum update -y
              sudo amazon-linux-extras install docker -y
              sudo service docker start
              sudo systemctl enable docker
              sudo usermod -a -G docker ec2-user
              touch file.txt

              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com

              echo "logged into aws and docker" >> file.txt

              docker pull ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/${aws_ecr_repository.ethereum.name}:stable
              echo "pulled the docker image from dockerhub" >> file.txt

              docker run -d -p 30303:30303 -v my_volume:/root/.ethereum ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/${aws_ecr_repository.ethereum.name}:stable

              EOF
}

resource "aws_vpc" "vpc-geth" {
  cidr_block =  "10.0.0.0/16" 
}

resource "aws_subnet" "subnet-geth" {
  vpc_id = aws_vpc.vpc-geth.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_security_group" "security-group-geth" {
  name        = "security-group-geth"
  vpc_id      = aws_vpc.vpc-geth.id

  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8545  
    to_port     = 8545
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  egress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
