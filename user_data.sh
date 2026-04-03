#!/bin/bash
# Simple user data script for EC2 instance bootstrapping
set -e

# update OS and install a minimal web server
yum update -y
amazon-linux-extras install -y nginx1
systemctl enable nginx
systemctl start nginx

echo "<h1>Terraform ASG Instance</h1>" > /usr/share/nginx/html/index.html
