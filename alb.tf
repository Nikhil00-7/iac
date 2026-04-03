resource "aws_alb" "alb" {
  name            = "my-alb"
  internal        = false
  security_groups = [aws_security_group.alb_sg.id]
  subnets         = [aws_subnet.public_subnet.id]

  tags = {
    Name = "my-alb"
  }
}

resource "aws_alb_target_group" "alb_target_group" {
  name     = "my-alb-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path     = "/health"
    protocol = "HTTP"
    matcher  = "200-299"
    port     = "3000"
  }
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb_target_group.arn
  }
}

