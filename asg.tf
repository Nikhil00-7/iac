resource "aws_launch_template" "asg_launch_template" {
  name_prefix   = "app_launch_template"
  image_id      = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"


  user_data              = filebase64("${path.module}/user_data.sh")
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "weather-aap-instance"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name             = "my-app-asg"
  max_size         = 3
  min_size         = 0
  desired_capacity = 0
  launch_template {
    id      = aws_launch_template.asg_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier       = [aws_subnet.private_subnet.id]
  target_group_arns         = [aws_alb_target_group.alb_target_group.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  tag {
    key                 = "Name"
    value               = "weather-app-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale_up_policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "scale_down_policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
}

resource "aws_autoscaling_policy" "Target_utilization_policy" {
  name                   = "target_utilization_policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }

}