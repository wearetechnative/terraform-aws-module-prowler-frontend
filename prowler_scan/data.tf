provider "aws" {
  alias  = "cloudfront"
  region = "us-east-1"
}

data "aws_prefix_list" "cloudfront" {
  provider = aws.cloudfront
  name     = "com.amazonaws.global.cloudfront.origin-facing"
}

data "aws_subnets" "public" {                                                                                                                                                                                                              
  filter {                                                                                                                                                                                                                                 
    name   = "vpc-id"                                                                                                                                                                                                                      
    values = [var.vpc_id]                                                                                                                                                                                                                  
  }                                                                                                                                                                                                                                        
  filter {                                                                                                                                                                                                                                 
    name   = "map-public-ip-on-launch"                                                                                                                                                                                                     
    values = ["true"]                                                                                                                                                                                                                      
  }                                                                                                                                                                                                                                        
}    

