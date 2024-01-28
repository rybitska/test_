output "geth_instance_id" {
  description = "The EC2 instance ID in with geth runs"
  value = aws_instance.geth.id
}

output "ws_url" {
  description = "The Web Socket URL for connecting to geth"
  value = aws_instance.geth.public_ip
}

output "http_url" {
  description = "The HTTP URL for connecting to geth"
  value = aws_instance.geth.public_ip
}
