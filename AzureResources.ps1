$resourceGroup='kube-demos'
$registryName='k8demos'
$aksCluster='kube-demos'
$network='myVnet'
$subnet='myAKSSubnet'
$virtualNodeSubnet='myVirtualNodeSubnet'
$email='petar.gjeorgiev@interworks.com.mk'

# Create resource group
az group create --name $resourceGroup --location WestEurope

# Check if there is acr provider 
az provider list > test.json
$obj1=Get-Content .`test.json | ConvertFrom-Json
$regState=$obj1 | Where-Object -Property namespace -eq Microsoft.ContainerInstance | Select-Object -Property registrationState
Remove-Item .`test.json

# If unregistered -register
if($regState.registrationState -eq 'Unregistered') {
    az provider register --namespace Microsoft.ContainerInstance
}

# Create virtual network
az network vnet create `
    --resource-group $resourceGroup `
    --name $network `
    --address-prefixes 10.0.0.0/8 `
    --subnet-name $subnet `
    --subnet-prefix 10.240.0.0/16

# Create virtual node subnet
az network vnet subnet create `
    --resource-group $resourceGroup `
    --vnet-name $network `
    --name $virtualNodeSubnet `
    --address-prefixes 10.241.0.0/16

# Create service principal (To allow AKS to interact with Azure resources AAD Service Principal is created)
$sp=az ad sp create-for-rbac --skip-assignment

$applicationId=$sp | ConvertFrom-Json | Select-Object -Property appId
$pwd=$sp | ConvertFrom-Json | Select-Object -Property password
$appId=$applicationId.appId
$password=$pwd.password

# Get virtualNetwork id
$vNetId=az network vnet show --resource-group $resourceGroup --name $network --query id -o tsv

# Grant the correct access for the AKS cluster to use the virtual network
az role assignment create --assignee $appId --scope $vNetId --role Contributor

# Get the ID of this subnet
$vSubnetId=az network vnet subnet show --resource-group $resourceGroup --vnet-name $network --name $subnet --query id -o tsv

# Create AKS cluster
az aks create `
    --resource-group $resourceGroup `
    --name $aksCluster `
    --node-count 1 `
    --generate-ssh-keys `
    --kubernetes-version 1.10.12 `
    --node-vm-size Standard_B2s `
    --network-plugin azure `
    --service-cidr 10.0.0.0/16 `
    --dns-service-ip 10.0.0.10 `
    --docker-bridge-address 172.17.0.1/16 `
    --vnet-subnet-id $vSubnetId `
    --service-principal $appId `
    --client-secret $password

# Enable Virtual Node addon
az aks enable-addons `
    --resource-group $resourceGroup `
    --name $aksCluster `
    --addons virtual-node `
    --subnet-name $virtualNodeSubnet

# Connect to the cluster
az aks get-credentials --resource-group $resourceGroup --name $aksCluster

# Get kubernetes nodes
kubectl get nodes

# Acr
az acr create --resource-group $resourceGroup --name $registryName --sku Basic --admin-enabled true
az acr login --name $registryName
$creds = az acr credential show --name $registryName
foreach($i in $creds) { $credToString += $i.ToString() }
$credsObj = ConvertFrom-Json -InputObject $credToString
$pass=$credsObj.passwords[0].value
$username=$credsObj.username
$loginServer=$registryName+ '.azurecr.io'
docker login $loginServer -u $username -p $pass

# Kubernetes dashboard
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
az aks browse --resource-group $resourceGroup --name $aksCluster

# Build image
docker build -t k8app:1 .

# Push to Azure Acr
docker tag k8app:1 $loginServer/k8app:1
docker push $loginServer/k8app:1

# Create acr secret
kubectl create secret docker-registry regcred --docker-server=$loginServer --docker-username=$username --docker-password=$pass --docker-email=$email

# Apply deployment
kubectl apply -f .`deployment.yaml

# Get pods
kubectl get pods -w

# Expose deployment
kubectl expose deployment k8app

# Edit service
kubectl edit service/k8app

# Get service (Wait for public ip to be exposed)
kubectl get service k8app -w

# Assign dns name
$publicId=az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[id]" --output tsv
az network public-ip update --ids $publicId --dns-name $aksCluster

# Cluster autoscale
kubectl autoscale deployment k8app --cpu-percent=5 --min=1 --max=10

# Get cluster autoscaler
kubectl get hpa k8app -o wide -w

# Get k8s service
$svc=kubectl get services k8app -o json | ConvertFrom-Json

# Run hey load tool for 20 min (https://github.com/rakyll/hey)
go get -u github.com/rakyll/hey
$siteUrl='http://'+$svc.status.loadBalancer.ingress.ip
hey -z 5m -c 100 $siteUrl

# Remove resource group
# az group delete --name $resourceGroup

$publicId=az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[id]" --output tsv
az network public-ip update --ids $publicId --dns-name $aksCluster