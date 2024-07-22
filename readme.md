## Azure Container Apps

Azure Container Apps is a fully managed application service provided by Microsoft Azure. It's based on Kubernetes, which is an open-source platform designed to automate deploying, scaling, and operating application containers.

Here are some key features of Azure Container Apps:

- **Fully Managed**: Azure Container Apps eliminates the need for you to manage the underlying infrastructure. It takes care of server management, networking, orchestration, and runtime.

- **Flexible Deployment**: You can deploy your applications directly from code or use Docker containers. It supports continuous deployment from Azure Pipelines, GitHub, Bitbucket, and more.

- **Built-in Security**: Azure Container Apps is secure by default. It automatically provides an HTTPS endpoint for your apps with a managed certificate.

- **Scaling**: It can automatically scale up or down based on the demand or a schedule. You only pay for the resources you use.

- **Integrated Developer Experience**: You can use familiar tools like the Azure CLI, Azure portal, or ARM templates to manage your applications.

- **Event-driven Architecture**: Azure Container Apps supports running jobs on-demand, on a schedule, or based on events. This makes it a good choice for microservices and serverless architectures.

- **Integration with Azure Ecosystem**: It works seamlessly with other Azure services like Azure Functions, Logic Apps, Event Grid, and more.


For more information please check [Microsoft Azure Update Manage Documentation](https://learn.microsoft.com/en-us/azure/container-apps/).

## Linter Status
[![Bicep Linter workflow](https://github.com/romanrabodzei/Azure-Container-Apps/actions/workflows/bicep_linter.yml/badge.svg)](https://github.com/romanrabodzei/Azure-Container-Apps/actions/workflows/bicep_linter.yml)&nbsp;&nbsp;[![Terraform Linter workflow](https://github.com/romanrabodzei/Azure-Container-Apps/actions/workflows/terraform_linter.yml/badge.svg)](https://github.com/romanrabodzei/Azure-Container-Apps/actions/workflows/terraform_linter.yml)