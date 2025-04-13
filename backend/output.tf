variable "my_cloud" {
  validation {
    condition = contains( ["aws" , "gcp" , "azure"] , lower(var.my_cloud))
    error_message = "cloud value must be from 'aws' , 'gcp' , 'azure' "
  }
   validation {
    condition = (length(var.my_cloud)>2) &&  (length(var.my_cloud)<5)
    error_message = "length of cloud inpput should be greatee than 2 and less than 5"
  }
}

# variable "check_cloud_input_length" {
#   validation {
#     condition = (length(var.my_cloud)>2) &&  (length(var.my_cloud)<5)
#     error_message = "length of cloud inpput should be greatee than 2 and less than 5"
#   }
# }