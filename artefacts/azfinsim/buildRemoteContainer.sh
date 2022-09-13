#!/bin/bash

# $1 - Name of the Azure Container Registry
# $2 - Name of Container Image
# $3 - Name of the (intermediate) build Azure Container Registry

echo "Started building image $2 on registry $3"

echo "Building image $2 on registry $3"

fullImage="$2:latest"
az acr build --registry $3 --image $fullImage -f Dockerfile.azfinsim https://github.com/utkarshayachit/azfinsim

echo 'Build finished'

echo "Import image on registry $1"
az acr import --name $1 --source "$3.azurecr.io/$fullImage"  --image $fullImage

echo 'Delete intermediate build Azure Container Registry'
az acr delete --name $3 --yes