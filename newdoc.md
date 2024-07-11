# Kong on EKS Cluster

(add pic)

## Introduction
Kong API Gateway is a lightweight, fast, and flexible cloud-native API gateway. Built on NGINX, it manages and secures APIs and microservices with high performance. Kong provides features like authentication, rate limiting, and logging, acting as a central point for API traffic management. Deploying Kong in Kubernetes leverages container orchestration, ensuring APIs are highly available, resilient, and scalable, simplifying API lifecycle management and enhancing system reliability.

## How Kong Operates
Kong acts as a mediator between clients and services, sitting in front of APIs to manage requests, authentication, rate limiting, and more. When a client makes a request, it goes through Kong, which routes the request to the appropriate service while applying security policies and other functionalities.

Kong has the following main components:

1. `Control Plane` manages and configures routes, services, and plugins, storing configuration data. It ensures the data plane enforces policies and interacts with the database, providing an Admin API for configuration management.

2. `Data Plane` processes incoming requests, routing them to appropriate services, and applies policies set by the control plane. It handles routing, authentication, and rate limiting, relying on the control plane for configuration updates without direct database interaction.

3. `Postgres` Database serves as the persistent storage backend, it stores all the configuration data, including routes, services, consumers, plugins, and credentials

## Prerequisites 
- Helm 
- Terraform


## Tested Versions 
| Kong Version    | Chart Version |
| --------        | -------       |
| 3.7.0           | 2.37.0        |
| 3.6.0           | 2.38.0        |

## Kong Architechture

(add pic)

## Kong Setup 

Retrieve files from the GitHub repository.

(add commands)

In the `tfvars` file, adjust the values according to the specific requirements. When deploying Kong on an existing Kubernetes cluster, update the `kube_config_path` variable to point to the configuration file of the target cluster. This ensures that Terraform and Helm commands are executed against the correct cluster. Configure the following flags as needed for the deployment:
- `create-eks`: Controls the creation of an EKS cluster.
- `create-kong`: Manages the deployment of Kong.
- `create-app`: Handles the deployment of an application.

Lastly, create an aws.sh file
```
export AWS_ACCESS_KEY_ID="YOUR-ACCESS-KEY"
export AWS_SECRET_ACCESS_KEY="YOUR-SECRET-ACCESS-KEY"
export AWS_REGION="YOUR-REGION"
```

Run the following command to execute the script
```
source aws.sh 
```
To apply the configuration files, follow these steps:

Initialize the directory and download necessary provider plugins:
```
terraform init
```
Generate an execution plan to preview infrastructure changes:
```
terraform plan
```
Apply the actions proposed in the Terraform plan:
```
terraform apply
```
Now, Terraform will provision the following resources on AWS.
1. VPC
2. Subnet
3. NAT Gateway
4. Internet Gateway
5. Elastic IP
6. Route Table
7. IAM Role & Policy
8. Security Group
9. Route53
10. EKS Cluster

## Kong Manager UI access (Optional)
Access the Kong Manager dashboard through a browser using the domain name.
- Open the web browser and enter https://kong-admin.kongtest.demo.cequence.ai. 
- Accessing the Kong Admin API first verifies Kong's correct operation and accessibility.
- Kong Manager's functionality depends on the Admin API; if the Admin API is not operational, Kong Manager cannot execute tasks.
- Open the web browser and enter https://kong-manager.kongtest.demo.cequence.ai.
- This action opens the Kong Manager dashboard in the default web browser, enabling direct testing and interaction.

The Kong Manager dashboard should appear as shown below.

(add pic)
