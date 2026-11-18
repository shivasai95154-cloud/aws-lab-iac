resource "aws_lb" "main" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false # internet-facing
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

locals {
  health_paths = {
    home = "/index.html"
    app1 = "/app1/index.html"
    app2 = "/app2/index.html"
  }
}

resource "aws_lb_target_group" "tg" {
  for_each = local.health_paths
  name     = "${var.name}-${each.key}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path                = each.value
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "server" {
  for_each         = local.servers
  target_group_arn = aws_lb_target_group.tg[each.value.role].arn
  target_id        = aws_instance.server[each.key].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg["home"].arn
  }
}

# Path-based routing: /app1* -> app1-tg, /app2* -> app2-tg
resource "aws_lb_listener_rule" "apps" {
  for_each     = { app1 = 10, app2 = 20 }
  listener_arn = aws_lb_listener.http.arn
  priority     = each.value
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[each.key].arn
  }
  condition {
    path_pattern { values = ["/${each.key}", "/${each.key}/*"] }
  }
}
