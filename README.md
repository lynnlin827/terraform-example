# Terraform Example

## Installation

```shell
$ brew install terraform
```

## Prerequisite

1. Create one security key to access AWS resources
2. (Optional) Create one SSH key to connect the AWS EC2
3. Rename `xxx.tfvars.example` to `xxx.tfvars` and assign the real value

## Command

```
$ terraform init
$ terraform apply CreateAnInstanceOnlyICanSSH
$ terraform destroy CreateAnInstanceOnlyICanSSH
```
