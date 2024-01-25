provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "ethereum_instance" {
  ami           = "ami-0a3c3a20c09d6f377"
  instance_type = "t2.medium"
  key_name      = ""
  security_group = ["your-security-group-id"]
  
  user_data = <<-EOF
              #!/bin/bash
              # sudo apt-get install
              # sudo apt-get updates
              # sudo add-apt-repository -y ppa:ethereum/ethereum 
              # sudo apt-get update
              # sudo apt-get install ethereum
              # sudo apt-get upgrade geth 
              # eth.syncing
              EOF
}

resource "aws_security_group" "ethereum_sg" {
  name        = "ethereum_sg"
  description = "Security group for Ethereum client"
  vpc_id      = "your-vpc-id"

  ingress {
    from_port = 30303
    to_port   = 30303
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8545
    to_port   = 8545
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
