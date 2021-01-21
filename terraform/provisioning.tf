####### provider  #######

provider "aws" {
  profile = "default"
  shared_credentials_file = "/var/credentials"
  region  = "ap-southeast-1"
}

####### s3 buckets #######

resource "aws_s3_bucket" "s3_file_upload" {
  bucket = "web-user-file-upload-bucket-121232"
  acl    = "private"
  tags = {
    "Terraform" : "true"
  }
}


resource "aws_s3_bucket" "lb_logs" {
  bucket = "alb-log-upload-bucket-121232"
  acl    = "public-read-write"
  tags = {
    "Terraform" : "true"
  }
}

########## public access block settings for S3 file upload bucket #############

resource "aws_s3_bucket_public_access_block" "s3_file_upload_public_access_block" {
  bucket = aws_s3_bucket.s3_file_upload.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}


###### bucket policy for log upload bucket ###########

# resource "aws_s3_bucket_policy" "bucket_policy_lb_logs" {
#   bucket = aws_s3_bucket.lb_logs.id

#   policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "AWS": "arn:aws:iam::114774131450:root"
#       },
#       "Action": "s3:PutObject",
#       "Resource": "arn:aws:s3:::alb-log-upload-bucket-121232/AWSLogs/400141859130/*"
#     },
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "delivery.logs.amazonaws.com"
#       },
#       "Action": "s3:PutObject",
#       "Resource": "arn:aws:s3:::alb-log-upload-bucket-121232/AWSLogs/400141859130/*",
#       "Condition": {
#         "StringEquals": {
#           "s3:x-amz-acl": "bucket-owner-full-control"
#         }
#       }
#     },
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "delivery.logs.amazonaws.com"
#       },
#       "Action": "s3:GetBucketAcl",
#       "Resource": "arn:aws:s3:::alb-log-upload-bucket-121232"
#     }
#   ]
# }
# POLICY
# }


##### set up networking ######

##### create vpc ##########

resource "aws_vpc" "sha_vpc" {
  cidr_block       = "192.168.0.0/16"
  enable_dns_hostnames = true

  tags = {
    "Terraform" = "true"
  }
}


##### create subnets ######

resource "aws_subnet" "subnet_az1" {
  vpc_id     = aws_vpc.sha_vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    "Terraform" = "true"
  }
}

resource "aws_subnet" "subnet_az2" {
  vpc_id     = aws_vpc.sha_vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    "Terraform" = "true"
  }
}

resource "aws_subnet" "subnet_az3" {
  vpc_id     = aws_vpc.sha_vpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-southeast-1c"

  tags = {
    "Terraform" = "true"
  }
}


###### internet gateway ###########

resource "aws_internet_gateway" "sha_igw" {
  vpc_id = aws_vpc.sha_vpc.id

  tags = {
     "Terraform" = "true"
  }
}

###### route table ###########

resource "aws_route_table" "sha_rt" {
    vpc_id = aws_vpc.sha_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.sha_igw.id
    }

    tags = {
        "Terraform" = "true"
    }
}

######## route table associations ###########

resource "aws_route_table_association" "sha_rta_subaz1_rt" {
    subnet_id = aws_subnet.subnet_az1.id
    route_table_id = aws_route_table.sha_rt.id
}


resource "aws_route_table_association" "sha_rta_subaz2_rt" {
    subnet_id = aws_subnet.subnet_az2.id
    route_table_id = aws_route_table.sha_rt.id
}

resource "aws_route_table_association" "sha_rta_subaz3_rt" {
    subnet_id = aws_subnet.subnet_az3.id
    route_table_id = aws_route_table.sha_rt.id
}


###### configure security group for ALB ############

resource "aws_security_group" "sha_alb_sg" {
  name = "alb-layer-sg"
  vpc_id = aws_vpc.sha_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    "Terraform" = "true"
  }
}


###### configure security group for instances #########

resource "aws_security_group" "sha_web_sg" {
  name = "web-layer-sg"
  vpc_id = aws_vpc.sha_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [ aws_security_group.sha_alb_sg.id ]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    "Terraform" = "true"
  }
}

########## create IAM access to S3 bucket #############

resource "aws_iam_user" "sha_s3_user" {
  name = "s3-user"

}
resource "aws_iam_policy_attachment" "s3_user_s3_access" {
  name       = "s3-user-s3-bucket-attach-policy"
  users      = [aws_iam_user.sha_s3_user.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_access_key" "sha_s3_user_keys" {
  user    = aws_iam_user.sha_s3_user.name
}

############## configure keys  ########################

resource "aws_key_pair" "ssh_keys" {
  key_name   = "web-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAlD6eAKko44VGHoo1m4uDJlZHaVFdIgIKKPxRUJgbncFnjc4HsLU+JhW3MlcQ1Xve7eT9VCT+tuid7GCi8NAM1BKYMsghckAJn/PfLVYX0YcONEiGemOMoLBFHRQo9CuhcXHXBuEmBaoEx/m3DRPTQ4OMt38GkZF3Sxja7eteOtrUKCcTfV+myCH7rmMyFjnIcOckJCqPoYNU44q9gj/uYeYpUC0+Q2XRz5GC+pCDxRn+VBxi9mmbwGbgGsDvCGgIxOOk1zFVix0vChzPVq5+StBHIgMA4RukZKUoXO3W7zlaO55rMoR/LM+6XYGE8xTFvnGeelTx6Hb44T3ZD/yUnw== web"
}


########## create launch configuration #################

resource "aws_launch_configuration" "web" {
  name = "web-application-launch-configuration"

  image_id = "ami-06fb5332e8e3e577a"
  instance_type = "t2.micro"

  security_groups = [ aws_security_group.sha_web_sg.id ]
  key_name = aws_key_pair.ssh_keys.id
  associate_public_ip_address = true
  user_data = <<USER_DATA
#!/bin/bash
apt-get update -y
apt-get upgrade -y
apt-get install -y automake autotools-dev fuse g++ git libcurl4-gnutls-dev libfuse-dev libssl-dev libxml2-dev make pkg-config nginx php7.2-fpm
git clone https://github.com/shan-siriwardana/web-application-deployment.git
cp -r web-application-deployment/web-application-files/default /etc/nginx/sites-available/default
cp web-application-deployment/web-application-files/home.php /var/www/html/
systemctl restart nginx
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse
./autogen.sh
./configure --prefix=/usr --with-openssl
make
make install
which s3fs
touch /etc/passwd-s3fs
echo "${aws_iam_access_key.sha_s3_user_keys.id}:${aws_iam_access_key.sha_s3_user_keys.secret}" > /etc/passwd-s3fs
chmod 640 /etc/passwd-s3fs
mkdir /mys3bucket
s3fs  -o url="https://s3-ap-southeast-1.amazonaws.com" -o endpoint=ap-southeast-1 -o dbglevel=info -o curldbg -o allow_other -o use_cache=/tmp -o umask=0000 web-user-file-upload-bucket-121232 /mys3bucket

  USER_DATA

  lifecycle {
    create_before_destroy = true
  }
}


############### create auto scaling group ######################

resource "aws_autoscaling_group" "sha_asg" {
  #availability_zones  = ["ap-southeast-1a","ap-southeast-1b","ap-southeast-1c"]
  vpc_zone_identifier = [aws_subnet.subnet_az1.id,aws_subnet.subnet_az2.id,aws_subnet.subnet_az3.id]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 2

  launch_configuration = aws_launch_configuration.web.name

}

############# create auto scaling policy ##########################

resource "aws_autoscaling_policy" "sha_web_as_policy" {
  name                   = "sha_web_as_policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.sha_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 40.0
  }
}

########### create ALB ######################

resource "aws_lb" "sha_frontend_alb" {
  name               = "sha-frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ aws_security_group.sha_alb_sg.id ]
  subnets            = [aws_subnet.subnet_az1.id,aws_subnet.subnet_az2.id,aws_subnet.subnet_az3.id]

  access_logs {
    bucket  = aws_s3_bucket.lb_logs.bucket
    prefix  = "test-lb"
    enabled = true
  }
}

############# create target group ##################

resource "aws_alb_target_group" "alb_target_group" {  
  name     = "sha-alb-target-group"  
  port     = "80"  
  protocol = "HTTP"  
  vpc_id   = aws_vpc.sha_vpc.id  

  health_check {    
    healthy_threshold   = 3    
    unhealthy_threshold = 10    
    timeout             = 5    
    interval            = 10    
    path                = "/"    
    port                = "80"  
  }
}

############ create listener ######################

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.sha_frontend_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb_target_group.arn
  }
}


########### create ASG attachment #############

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.sha_asg.id
  alb_target_group_arn   = aws_alb_target_group.alb_target_group.arn
}
