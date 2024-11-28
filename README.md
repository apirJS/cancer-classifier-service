# Terraform project
### Skin cancer classification app
![Dicoding Academy](https://dicoding-web-img.sgp1.cdn.digitaloceanspaces.com/original/academy/dos-5ec56ee9e3227762be5d6e7693699d2120240110160337.jpeg)

#### Create ```terraform/terraform.tfvars``` 
```bash
service_account_key = "path/to/serviceaccountkey.json"
project_id          = "project"
region              = "region"
zone                = "zone"
```

#### Enable required APIs
```bash
gcloud services enable artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    appengine.googleapis.com \
    firestore.googleapis.com \
    run.googleapis.com \
    storage.googleapis.com
```
#### Grant necessary roles to the service account
```bash
App Engine Admin
App Engine Creator
Artifact Registry Administrator
Cloud Datastore Owner
Cloud Run Admin
Service Account User
Service Usage Admin
Storage Admin
```

#### Run terraform
```bash
terraform init

terraform plan

terraform apply
```

#### Specify your bucket path on src/index.ts

#### Change paths on main.tf file

#### Note: ```I don't know why app engine is not working. But anything other than that is working```
