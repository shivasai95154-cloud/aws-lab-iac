output "alb_url" {
  value = "http://${aws_lb.main.dns_name}/"
}
output "instance_ids" {
  value = { for k, v in aws_instance.server : k => v.id }
}
