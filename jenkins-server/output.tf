output "public_ip" {
  value = module.ec2_instance.public_ip
}
output "aws_availability_zones" {
  value = data.aws_availability_zones.azs.names
}
output "aws_ami" {
  value = data.aws_ami.ubuntu

}
output "private_route_table" {
  value = module.vpc.private_route_table_ids
}