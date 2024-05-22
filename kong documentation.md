# Kong API Gateway on Kubernetes: A Practical Guide
## Introduction
Kong API Gateway is a light weight, fast, and flexible cloud native API gateway. It is a powerful and scalable open-source platform designed to manage and secure APIs and microservices. Built on top of NGINX, it provides high performance and flexibility, making it ideal for modern, distributed architectures. Kong acts as a central point for managing API traffic, providing features like authentication, rate limiting, logging, and more, which help streamline API management and improving security. By deploying Kong API Gateway in Kubernetes, you can leverage the advantages of container orchestration and microservices architecture, ensuring your APIs are highly available, resilient, and scalable. This integration simplifies the process of managing API lifecycles, enables seamless scaling, and enhances overall system reliability.

## KONG: why is it important
Kong API Gateway stands out as an advanced solution for API management, offering a suite of features including flexible request routing, automatic service discovery, advanced load balancing, API management, real-time analytics, and monitoring. These capabilities empower organizations to efficiently handle API traffic, discover and register APIs, distribute traffic across backend services, manage APIs throughout their lifecycle, and gain valuable insights into API performance and usage. With its extensive range of plugins, Kong enables easy customization, adding functionalities like authentication, rate limiting, and transformations. Moreover, Kong's flexible deployment options cater to diverse organizational needs, whether it's on-premises, in the cloud, or as a managed service. Enhanced security features such as authentication, authorization, encryption, and rate limiting further safeguard sensitive data and mitigate potential API attacks. Kong API Gateway thus emerges as a highly effective solution for organizations seeking to establish and maintain a robust API infrastructure.

## Pre-requisites
- Kubernetes
- Helm
- PostgreSQL
- Terraform (for automated setup)

## Version
`3.6.1`

## Kong Deployment Architechture
![arch]([https://example.com/photo.jpg](https://github.com/Divya-1004/Kong/blob/main/architechture.png))

## Kong Setup 
The following are the two primary deployment methods for deploying the Kong API Gateway:
1. Manual Setup
2. Automated Setup via Terraform
### Manual Setup
Below are the detailed steps for manually deploying the Kong API Gateway.

#### Helm Setup
Kong provides a Helm chart to deploy the Kong Gateway.\
Adding a repository to our machine.
Now we will install Kong using Helm chart.
```
helm repo add kong https://charts.konghq.com
helm repo update
```
#### Secret 
Next, a secret is created that allows Kong Gateway Enterprise instances to authenticate and enable Enterprise features.

First, create a namespace
```
kubectl create namespace kong 
```
Next, create a kong gateway enterprise license secret
```
kubectl create secret generic kong-enterprise-license --from-literal=license="'{}'" -n kong
```
#### Clustering Certificates
Generating a TLS certificate and creating a Kubernetes secret containing the certificate is necessary when setting up Kong clustering in a secure manner.

Generate a TLS certificate using OpenSSL. 
```
openssl req -new -x509 -nodes -newkey ec:<(openssl ecparam -name secp384r1) -keyout ./tls.key -out ./tls.crt -days 1095 -subj "/CN=kong_clustering" 
```

Then, create a kubernetes secret containing the certificate 
```
kubectl create secret tls kong-cluster-cert --cert=./tls.crt --key=./tls.key -n kong 
```
#### Installation
##### Control Plane
The Control Plane enables administrators to efficiently manage and operate Kong instances across distributed environments\
Create a Values-cp.yaml file with the following script contents.
```
ingressController:
 enabled: true
  
image:
 repository: kong
 tag: "3.6.1"
  
# Mount the secret created earlier
secretVolumes:
 - kong-cluster-cert
  
env:
 # This is a control_plane node
 role: control_plane
 # These certificates are used for control plane / data plane communication
 cluster_cert: /etc/secrets/kong-cluster-cert/tls.crt
 cluster_cert_key: /etc/secrets/kong-cluster-cert/tls.key
  
 # Database
 # CHANGE THESE VALUES
 database: postgres
 pg_database: kong
 pg_user: kong
 pg_password: demo123
 pg_host: kong-cp-postgresql.kong.svc.cluster.local
 pg_ssl: "on"
  
 # Kong Manager password
 password: kong_admin_password
  
# Enterprise functionality
enterprise:
 enabled: true
 license_secret: kong-enterprise-license
  
# The control plane serves the Admin API
admin:
 enabled: true
 http:
   enabled: true
  
# Clustering endpoints are required in hybrid mode
cluster:
 enabled: true
 tls:
   enabled: true
  
clustertelemetry:
 enabled: true
 tls:
   enabled: true
  
# Optional features
manager:
 enabled: false
  
# These roles will be served by different Helm releases
proxy:
 enabled: false
```
To deploy a Postgres database within the cluster for testing purposes, add the following to the bottom of values-cp.yaml.
```
# This is for testing purposes only
# DO NOT DO THIS IN PRODUCTION
# Your cluster needs a way to create PersistentVolumeClaims
# if this option is enabled
postgresql:
  enabled: true
  auth:
    password: demo123
```
To create a Helm release, 
```
helm install kong-cp kong/kong -n kong --values ./values-cp.yaml 
```
To ensure the control plane pod is running as expected, 
```
kubectl get pods -n kong
```
##### Data Plane
The Data Plane is responsible for handling the actual API traffic.\
Create a Values-dp.yaml file with the following script contents.
```
ingressController:
 enabled: false
  
image:
 repository: kong/kong-gateway
 tag: "3.6.1.4"
  
# Mount the secret created earlier
secretVolumes:
 - kong-cluster-cert
  
env:
 # data_plane nodes do not have a database
 role: data_plane
 database: "off"
  
 # Tell the data plane how to connect to the control plane
 cluster_control_plane: kong-cp-kong-cluster.kong.svc.cluster.local:8005
 cluster_telemetry_endpoint: kong-cp-kong-clustertelemetry.kong.svc.cluster.local:8006
  
 # Configure control plane / data plane authentication
 lua_ssl_trusted_certificate: /etc/secrets/kong-cluster-cert/tls.crt
 cluster_cert: /etc/secrets/kong-cluster-cert/tls.crt
 cluster_cert_key: /etc/secrets/kong-cluster-cert/tls.key
  
# Enterprise functionality
enterprise:
 enabled: true
 license_secret: kong-enterprise-license
  
# The data plane handles proxy traffic only
proxy:
 enabled: true
  
# These roles are served by the kong-cp deployment
admin:
 enabled: false
  
manager:
 enabled: false

```
To create a Helm release, 
```
helm install kong-dp kong/kong -n kong --values ./values-dp.yaml 
```
#### Testing
Open another terminal and run this command to set up port forwarding and access the admin API.
```
kubectl port-forward -n kong service/kong-cp-kong-admin 8001
```
#### Configuring Admin API
Kong Gateway is running on Kubernetes, with the Admin API exposed as a NodePort service, making it inaccessible from outside the cluster. Meanwhile, the proxy service is exposed via a LoadBalancer, providing a public address. To enable access to the Admin API without relying on kubectl port-forward, you can set up an internal load balancer on your cloud provider. This configuration is necessary for accessing Kong Manager to view or edit your settings.\
Fetch the Ingress IP address and update your DNS records to point to this address.
```
kubectl get ingress -n kong kong-cp-kong-admin -o jsonpath='{.spec.rules[0].host}{": "}{range .status.loadBalancer.ingress[0]}{@.ip}{@.hostname}{end}'
```
Configure your ingress controller\
Set ingressController.enabled to true in your values-cp.yaml file to enable Kong Ingress Controller.\
```
ingressController:
enabled: true
env:
   publish_service: kong/kong-dp-kong-proxy
   kong_admin_token: kong_admin_password
```
```
admin:
enabled: true
http:
   enabled: true
tls:
   enabled: false
ingress:
   enabled: true
   hostname: admin.example.com
   path: /
   pathType: Prefix
   ingressClassName: kong
```
`Note to replace example.com with your custom domain name.`

Updating the Helm release 
```
helm upgrade kong-cp kong/kong -n kong --values ./values-cp.yaml
```
Fetch the Ingress IP address and update your DNS records to point to the Ingress address.
```
 kubectl get ingress -n kong kong-cp-kong-admin -o jsonpath='{.spec.rules[0].host}{": "}{range .status.loadBalancer.ingress[0]}{@.ip}{@.hostname}{end}'
```
#### Kong Manager Installation 
Kong gateway is now installed.\
Make sure that Kong's Admin API is accessible via HTTP from your local machine.\

Kong Manager is hosted on the same node as the Admin API. To enable Kong Manager, modify your values-cp.yaml file as follows.\

Set admin_gui_url, admin_gui_api_url and admin_gui_session_conf under the env key.
```
env:
  admin_gui_url: http://manager.example.com
  admin_gui_api_url: http://admin.example.com
  # Change the secret and set cookie_secure to true if using a HTTPS endpoint
  admin_gui_session_conf: '{"secret":"secret","storage":"kong","cookie_secure":false}'
```
` Note to replace example.com in the configuration with your domain.`
Enable Kong Manager authentication under the enterprise key.
```
enterprise:
  rbac:
    enabled: true
    admin_gui_auth: basic-auth
```
Configure the manager section in values-cp.yaml. 
```
manager:
 enabled: true
 http:
   enabled: true
 tls:
   enabled: false
    
 ingress:
   enabled: true
   hostname: manager.example.com
   path: /
   pathType: Prefix
   ingressClassName: alb
   annotations:
     alb.ingress.kubernetes.io/load-balancer-name: kong-alb-private
     alb.ingress.kubernetes.io/group.name: demo.kong-alb-private
     alb.ingress.kubernetes.io/target-type: instance
     alb.ingress.kubernetes.io/scheme: internal
     alb.ingress.kubernetes.io/healthcheck-path: /
     alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
```
Updating the Helm release 
```
helm upgrade kong-cp kong/kong -n kong --values ./values-cp.yaml
```
Fetch the Ingress IP address and update your DNS records to point to this address.
```
kubectl get ingress -n kong kong-cp-kong-manager -o jsonpath='{.spec.rules[0].host}{": "}{range .status.loadBalancer.ingress[0]}{@.ip}{@.hostname}{end}'
```
#### Testing
Open a web browser and visit the URL specified in `env.admin_gui_url` to access the Kong Manager login page. The default username is `kong_admin`, and the password is the one you set in `env.password` during the installation of the Kong Gateway control plane in the previous step.


The final `values-cp.yaml` file should look like this:
```
ingressController: 
  enabled: true 
  env: 
    publish_service: kong/kong-dp-kong-proxy 
    kong_admin_token: kong_admin_password 
  
image: 
  repository: kong 
  tag: "3.6.1" 
 
# Mount the secret created earlier 
secretVolumes: 
  - kong-cluster-cert 
  
env: 
  admin_gui_url: http://15.235.143.186:30769 
  admin_gui_api_url: http://15.235.143.186:31575 
  admin_gui_session_conf: '{"secret":"secret","storage":"kong","cookie_secure":false}' 
  # This is a control_plane node 
  role: control_plane 
  # These certificates are used for control plane / data plane communication 
  cluster_cert: /etc/secrets/kong-cluster-cert/tls.crt 
  cluster_cert_key: /etc/secrets/kong-cluster-cert/tls.key  

  # Database 
  # CHANGE THESE VALUES 
  database: postgres 
  pg_database: kong 
  pg_user: kong 
  pg_password: demo123 
  pg_host: kong-cp-postgresql.kong.svc.cluster.local 
  pg_ssl: "on" 
 
  # Kong Manager password 
  password: kong_admin_password 
 
enterprise: 
  enabled: false 
  license_secret: kong-enterprise-license 
  
admin: 
  enabled: true 
  http: 
    enabled: true 
  tls: 
    enabled: false 
  ingress: 
    enabled: true 
    hostname: admin.example.com 
    path: / 
    pathType: Prefix 
    ingressClassName: kong 
 
cluster: 
  enabled: true 
  tls: 
    enabled: true 
  
clustertelemetry: 
  enabled: true 
  tls: 
    enabled: true 
 
manager: 
  enabled: true 
  http: 
    enabled: true 
  tls: 
    enabled: false 

  ingress: 
    enabled: true 
    hostname: manager.example.com 
    path: / 
    pathType: Prefix 
    ingressClassName: kong 
  
proxy: 
  enabled: false 
  
postgresql: 
   enabled: true 
   auth: 
     password: demo123 
```
The final `values-dp.yaml` file should look like this:
```
# Do not use Kong Ingress Controller
ingressController:
 enabled: false

image:
 repository: kong/kong-gateway
 tag: "3.6.1.3"

# Mount the secret created earlier
secretVolumes:
 - kong-cluster-cert

env:
 # data_plane nodes do not have a database
 role: data_plane
 database: "off"

 # Tell the data plane how to connect to the control plane
 cluster_control_plane: kong-cp-kong-cluster.kong.svc.cluster.local:8005
 cluster_telemetry_endpoint: kong-cp-kong-clustertelemetry.kong.svc.cluster.local:8006

 # Configure control plane / data plane authentication
 lua_ssl_trusted_certificate: /etc/secrets/kong-cluster-cert/tls.crt
 cluster_cert: /etc/secrets/kong-cluster-cert/tls.crt
 cluster_cert_key: /etc/secrets/kong-cluster-cert/tls.key

# Enterprise functionality
enterprise:
 enabled: false
 license_secret: kong-enterprise-license

# The data plane handles proxy traffic only
proxy:
 enabled: true

# These roles are served by the kong-cp deployment
admin:
 enabled: false

manager:
 enabled: false
```

### Automated Setup 

#### Why Automate Kong?
Automating the Kong API Gateway provides numerous advantages that enhance overall efficiency and effectiveness. By automating deployment and management tasks, organizations can significantly reduce the time and effort required for setup and updates. This not only simplifies the initial setup process but also ensures that any changes or scaling requirements can be implemented quickly and reliably. Consistent configurations minimize human errors, which is crucial for maintaining reliability and availability, as automated monitoring and management promptly detect and resolve issues. Additionally, automation facilitates scalability, allowing the gateway to handle increasing traffic and expanding infrastructure with ease. Security is also enhanced through the consistent application of security policies and updates. Overall, automation reduces operational costs and increases efficiency, making it a vital strategy for organizations seeking a robust and scalable API management solution.

#### Terraform 
Terraform serves as a widely-utilized infrastructure-as-code (IAC) tool, which effectively automates the provisioning and management of infrastructure resources. It empowers DevOps teams to articulate the desired state of their infrastructure through configuration files written in HashiCorp Configuration Language (HCL). Primarily, Terraform finds application in public cloud provisioning on major providers, effectively streamlining and automating various infrastructure tasks to boost efficiency and ensure consistency.

#### Steps to Automate Kong via Terraform 
Create a directory named `helm-kong`.
```
mkdir helm-kong  
cd helm-kong
```
Within this directory, create a file named `main.tf` and add the following script to it.
```
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Terraform code to generate TLS certificate and key using OpenSSL and create a Kubernetes secret
# Create a provider configuration if needed
# Generate the self-signed TLS certificate and key
resource "tls_private_key" "tls_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384" # Use the secp384r1 curve
}

resource "tls_self_signed_cert" "tls_cert" {
  private_key_pem = tls_private_key.tls_key.private_key_pem
  allowed_uses    = [
    "cert_signing",
    "crl_signing",
    "code_signing",
    "server_auth",
    "client_auth",
    "digital_signature",
    "key_encipherment",
  ]
  subject {
    common_name = "kong_clustering"
  }

  validity_period_hours = 1095 * 24 # 1095 days
}

# Create Kubernetes secret for TLS certificate and key
resource "kubernetes_secret" "kong_cluster_cert" {
  metadata {
    name      = "kong-cluster-cert"
    namespace = "kong"
  }

  data = {
    "tls.crt" = tls_self_signed_cert.tls_cert.cert_pem
    "tls.key" = tls_private_key.tls_key.private_key_pem
  }
}

resource "null_resource" "secret" {
  # This resource is used to execute a local command to create the Kubernetes secret
  triggers = {
    # Trigger the command execution whenever the TLS certificate or key changes
    tls_certificate_key = "${tls_self_signed_cert.tls_cert.cert_pem}${tls_private_key.tls_key.private_key_pem}"
  }

provisioner "local-exec" {
    command = <<-EOT
      echo "${tls_self_signed_cert.tls_cert.cert_pem}" > /tmp/tls.crt
      echo "${tls_private_key.tls_key.private_key_pem}" > /tmp/tls.key
      kubectl create secret tls kong-cluster-cert \
        --cert=/tmp/tls.crt \
        --key=/tmp/tls.key \
        -n kong
      rm /tmp/tls.crt /tmp/tls.key
    EOT
  }
}

resource "helm_release" "kong" {
  name             = "kong-cp"
  repository       = "https://charts.konghq.com"
  chart            = "kong"
  create_namespace = "true"
  namespace        = "kong"
  values = [
    "${file("values-cp.yaml")}"
  ]
  depends_on = [null_resource.secret]
}
```
Next, create a file named `values-cp.yaml` in the same directory and include the script below.
```
ingressController:
  enabled: true
  env:
    publish_service: kong/kong-dp-kong-proxy
    kong_admin_token: kong_admin_password

image:
  repository: kong
  tag: "3.6.1"

# Mount the secret created earlier
secretVolumes:
  - kong-cluster-cert

env:
  admin_gui_url: http://15.235.143.186:31387
  admin_gui_api_url: http://15.235.143.186:31555
  admin_gui_session_conf: '{"secret":"secret","storage":"kong","cookie_secure":false}'
  # This is a control_plane node
  role: control_plane
  # These certificates are used for control plane / data plane communication
  cluster_cert: /etc/secrets/kong-cluster-cert/tls.crt
  cluster_cert_key: /etc/secrets/kong-cluster-cert/tls.key

  # Database
  # CHANGE THESE VALUES
  database: postgres
  pg_database: kong
  pg_user: kong
  pg_password: demo123
  pg_host: kong-cp-postgresql.kong.svc.cluster.local
  pg_ssl: "on"

  # Kong Manager password
  password: kong_admin_password

enterprise:
  enabled: false
  license_secret: kong-enterprise-license

admin:
  enabled: true
  http:
    enabled: true
  tls:
    enabled: false
  ingress:
    enabled: true
    hostname: admin.example.com
    path: /
    pathType: Prefix
    ingressClassName: kong

cluster:
  enabled: true
  tls:
    enabled: true

clustertelemetry:
  enabled: true
  tls:
    enabled: true

manager:
  enabled: true
  http:
    enabled: true
  tls:
    enabled: false

  ingress:
    enabled: true
    hostname: manager.example.com
    path: /
    pathType: Prefix
    ingressClassName: kong

proxy:
  enabled: false

postgresql:
   enabled: true
   auth:
     password: demo123
```
Then, create another file named `values-dp.yaml` and add the provided script to it.
```
# Do not use Kong Ingress Controller
ingressController:
 enabled: false

image:
 repository: kong/kong-gateway
 tag: "3.6.1.3"

# Mount the secret created earlier
secretVolumes:
 - kong-cluster-cert

env:
 # data_plane nodes do not have a database
 role: data_plane
 database: "off"

 # Tell the data plane how to connect to the control plane
 cluster_control_plane: kong-cp-kong-cluster.kong.svc.cluster.local:8005
 cluster_telemetry_endpoint: kong-cp-kong-clustertelemetry.kong.svc.cluster.local:8006

 # Configure control plane / data plane authentication
 lua_ssl_trusted_certificate: /etc/secrets/kong-cluster-cert/tls.crt
 cluster_cert: /etc/secrets/kong-cluster-cert/tls.crt
 cluster_cert_key: /etc/secrets/kong-cluster-cert/tls.key

# Enterprise functionality
enterprise:
 enabled: false
 license_secret: kong-enterprise-license

# The data plane handles proxy traffic only
proxy:
 enabled: true

# These roles are served by the kong-cp deployment
admin:
 enabled: false

manager:
 enabled: false
```
To apply these configuration files:
- Run `terraform init` to initialize the directory and download the necessary provider plugins.\
- Run `terraform plan` to generate an execution plan, allowing you to preview the changes Terraform will make to your infrastructure.\
- Run `terraform apply` to execute the actions proposed in the Terraform plan.\
![img](https://github.com/Divya-1004/Kong/blob/main/image.png)

#### Testing
To test your Kong Gateway's dashboard, you need to access it in your browser using the NodePort IP address and port assigned by Kubernetes. \
- Open your browser and enter `NodeIP:NodePort`.\
- For instance, if your node IP is 192.168.99.100 and your NodePort is 32444, you would enter 192.168.99.100:32444 in your browser.\
- This will open your Kong Admin dashboard in your default web browser, allowing you to test and interact with it directly.\

The Kong Admin dashboard should appear as shown below.

![test](https://github.com/Divya-1004/Kong/blob/main/testing.png)


## Conclusion
Kong API Gateway functions as an intermediary between clients and backend services, effectively managing API traffic. It operates on a plugin-based architecture, allowing developers to extend its functionality according to specific requirements. It offers various features including routing, authentication, rate limiting, logging, and caching, all crucial for API management. Kong relies on a datastore, typically PostgreSQL or Cassandra, to store configuration data and runtime information. Kong provides a user-friendly Admin API and Dashboard for configuration management and monitoring. Overall, Kong's architecture and feature set make it a versatile and powerful tool for managing APIs in a scalable and efficient manner.
