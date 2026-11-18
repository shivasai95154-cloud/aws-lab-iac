data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Lets you open a shell via Session Manager (no SSH keys needed)
resource "aws_iam_role" "ssm" {
  name = "${var.name}-ec2-ssm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name}-ec2-ssm"
  role = aws_iam_role.ssm.name
}

locals {
  # 3 public + 3 private servers: one of each per page
  servers = {
    home-public  = { role = "home", subnet_id = aws_subnet.public[0].id }
    home-private = { role = "home", subnet_id = aws_subnet.private[0].id }
    app1-public  = { role = "app1", subnet_id = aws_subnet.public[1].id }
    app1-private = { role = "app1", subnet_id = aws_subnet.private[1].id }
    app2-public  = { role = "app2", subnet_id = aws_subnet.public[0].id }
    app2-private = { role = "app2", subnet_id = aws_subnet.private[0].id }
  }
  dest_dir = {
    home = "/usr/share/nginx/html"
    app1 = "/usr/share/nginx/html/app1"
    app2 = "/usr/share/nginx/html/app2"
  }
}

resource "aws_instance" "server" {
  for_each               = local.servers
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = each.value.subnet_id
  vpc_security_group_ids = [aws_security_group.instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  # Installs nginx and writes the page from /web, with the ALB DNS name filled in
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    dest_dir = local.dest_dir[each.value.role]
    page     = replace(file("${path.module}/../web/${each.value.role}.html"), "__ALB_DNS__", aws_lb.main.dns_name)
  })
  user_data_replace_on_change = true

  tags       = { Name = "${var.name}-${each.key}" }
  depends_on = [aws_nat_gateway.nat, aws_route.private_nat]
}
