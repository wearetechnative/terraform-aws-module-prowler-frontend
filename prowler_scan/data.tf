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

