#generate all variables 
variable "vpc_cidr_block" {
    type = string
    default =  "10.0.0.0/16"
}
variable "public_subnets" {
    type = list(string)
    default = ["10.0.1.0/24"]
}
variable "private_subnets" {
    type = list(string)
    default = ["10.0.2.0/24"]
}
variable "instance_type" {
    type = string
    default = "t3.large"
}
variable "key_name" {
    type = string
    default = "techkey"
}
