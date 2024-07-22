
# Recommendation: Overwrite the default in tfvars or stick with the automatic default
variable "tf_last_updated" {
    type = string
    default = ""
    description = "Set this (e.g. in terraform.tfvars) to set the value of the tf_last_updated tag for all resources. If unset, the current date/time is used automatically."
}
# Recommendation: Overwrite the default in tfvars or by specify an environment variable TF_VAR_aws_region
variable "aws_region" {
    type = string
    default = "eu-central-1"
    description = "The AWS region to be used"
}

variable "purpose" {
    type = string
    default = "Testing"
    description = "The purpose of this configuration, used e.g. as tags for AWS resources"
}

variable "username" {
    type = string
    default = ""
    description = "Username, used to define local.username if set here. Otherwise, the logged in username is used."
}

variable "owner" {
    type = string
    default = ""
    description = "All resources are tagged with an owner tag. If none is provided in this variable, a useful value is derived from the environment"
}

# The validator uses a regular expression for valid email addresses (but NOT complete with respect to RFC 5322)
variable "owner_email" {
    type = string
    default = ""
    description = "All resources are tagged with an owner_email tag. If none is provided in this variable, a useful value is derived from the environment"
    validation {
        condition = anytrue([
            var.owner_email=="",
            can(regex("^[a-zA-Z0-9_.+-]+@([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9]+)*\\.)+[a-zA-Z]+$", var.owner_email))
        ])
        error_message = "Please specify a valid email address for variable owner_email or leave it empty"
    }
}

variable "owner_fullname" {
    type = string
    default = ""
    description = "All resources are tagged with an owner_fullname tag. If none is provided in this variable, a useful value is derived from the environment"
}

variable "resource_prefix" {
    type = string
    default = ""
    description = "This string will be used as prefix for generated resources. Default is to use the username"
}

variable "public_ssh_key" {
    type = string
    default = ""
    description = "Public SSH key to use. If not specified, use either $HOME/.ssh/id_ed25519.pub or if that does not exist: $HOME/.ssh/id_rsa.pub"
}

variable "ccloud_audit_log_bootstrap_server" {
    type = string
    description = "ID of the Confluent Cloud environment to use"
}

variable "ccloud_audit_log_api_key" {
    type = object({
      key       = string,
      secret       = string
    })
    description = "The audit log API key"
    sensitive = true
}

variable "ccloud_cluster_audit_log_topic" {
    type = string
    default = "confluent-audit-log-events"
    description = "The name of the Kafka audit log topic to subscribe to. No need to ever change this"
}

variable "ccloud_cluster_generate_client_config_files" {
    type = bool
    default = false
    description = "Set to true if you want to generate client configs with the created API keys under subfolder \"generated/client-configs\""
}

variable "aws_lambda_function_name" {
    type = string
    default = "example-kafka-lambda-audit-log"
    description = "The name of the lambda function. Please use only alphanumeric characters and hyphens (due to a limitation of S3 naming conventions)"
}

variable "aws_lambda_handler_class_name" {
    type = string
    default = "io.confluent.example.aws.lambda.auditlog.LambdaConfluentAuditLogToCloudWatch"
    description = "The name of the lambda class"
}

variable "aws_lambda_trigger_enabled" {
    type = bool
    default = true
    description = "Set this to false to disable the trigger for this lambda. This has been added for making testing more convenienty"
}

variable "aws_lambda_cloudwatch_audit_log_group" {
    type = string
    default = "/confluent/example/auditlog"
    description = "The CloudWatch group to write audit log data to. If you chance the default, update the source code, too."
}
