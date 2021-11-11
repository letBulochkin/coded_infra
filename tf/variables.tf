variable "access_key" {
    type = string
    description = "AWS Access Key"
}

variable "secret_key" {
    type = string
    description = "AWS Secret Key"
}

variable "region" {
    type = string
    description = "AWS Region"
}

variable "ec2_url" {
    type = string
    description = "EC2 API URL"
}

variable "s3_url" {
    type = string
    description = "S3 API URL"
}

variable "stand_name" {
    type = string
    description = "Stand name."
}

variable "azs" {
    type = list
    description = "Availability zones' names in multi-AZ deployment."
}

variable "ssh_key" {
    type = string
    description = "SSH key name"
}

variable "template_centos75" {
    type = string
    description = "Template ID for CentOS 7.5"
}

variable "s3_endpoint_address" {
    type = string
    description = "S3 bucket endpoint address"
}

variable "s3_website_endpoint_address" {
    type = string
    description = "S3 bucket-as-website endpoint address"
}
