terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
     github = {
      source = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
    region = "us-east-1"
  }
provider "github" {
  token = "********"
}

resource "github_repository" "myrepo" {
    name = "bookstore-api"
    auto_init = true
    visibility = "private"
  
}

resource "github_branch_default" "main" {
    branch = "main"
    repository = github_repository.myrepo.name   
}
variable "files" {
    default = ["bookstore-api.py", "requirements.txt", "Dockerfile", "docker-compose.yml"]

}

#terraform registry den bakabiliriz github  repoya nasil file lari ekleyecegiz mesela. simdi sirada bunu yapiyoruz:
resource "github_repository_file" "app-files" {
    for_each = toset(var.files)
    content = file(each.value)
    file = each.value
    repository = github_repository.myrepo.name
    branch = "main"
    commit_message = "managed by terraform"
    overwrite_on_create = true  
}

resource "aws_instance" "tf-docker-ec2" {
    ami = "ami-00c39f71452c08778"
    instance_type = "t2.micro"
    key_name = "****"
    vpc_security_group_ids = [aws_security_group.tf-docker-sec-gr.id]
    tags = {
        Name = "Web server of Bookstore"
    }


  user_data = <<-EOF
            #! /bin/bash
            yum update -y
            yum install docker -y
            systemctl start docker
            systemctl enable docker
            usermod -a -G docker ec2-user
            newgrp docker
            #simdi docker-compose u install edecegiz 
            curl -SL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            mkdir -p /home/ec2-user/bookstore-api
            TOKEN="***************"
            FOLDER="https://$TOKEN@raw.githubusercontent.com/hanifezeray/bookstore-api/main/"
            #curl deki o flag i ile mesela github dan aldigimiz bookstore-api.py yi app-py ile copy yapabiliriz ec2 instance imiza.
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/app.py" -L "$FOLDER"bookstore-api.py 
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/requirements.txt" -L "$FOLDER"requirements.txt
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/Dockerfile" -L "$FOLDER"Dockerfile
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/docker-compose.yml" -L "$FOLDER"docker-compose.yml
            cd /home/ec2-user/bookstore-api
            docker build -t hanifezry/bookstoreapi:latest .
            docker-compose up -d
            EOF
  depends_on = [ github_repository.myrepo, github_repository_file.app-files ]
  #once github repo ve icindeki file lar olussun ki sonra ec2 olussun diye depends_on deyip belirtiyoruz

}

resource "aws_security_group" "tf-docker-sec-gr" {
    name = "docker-sec-gr-proje203"
    tags = {
      Name = "docker-sec-gr-proje203"
    }

    ingress  {
        from_port   = 80
        protocol    = "tcp"
        to_port     = 80
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress  {
       from_port   = 22
       protocol    = "tcp"
       to_port     = 22
       cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
       from_port   = 0
       protocol    = "-1"
       to_port     = 0
       cidr_blocks = ["0.0.0.0/0"]
  }
}

output "website" {
    value = "http://${aws_instance.tf-docker-ec2.public_ip}"
  
}