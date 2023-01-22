# AWS

```sh
devenv shell
# cd to appropriate dir
terraform init
terraform plan
terraform appy
```

## Environment variables

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

## Reading outputs

```
devenv shell
terraform output
# If you need access to sensitive output
terraform output -json
```
