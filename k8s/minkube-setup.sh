#!/bin/bash
# Setup script for local Kubernetes development with minikube

echo "🚀 Setting up Travel Analytics on minikube..."

# Check if minikube is running
if ! minikube status | grep -q "host: Running"; then
    echo "Starting minikube..."
    minikube start --cpus=2 --memory=4096 --driver=docker
fi

# Use minikube's Docker daemon
eval $(minikube docker-env)

# Build Docker image inside minikube
echo "📦 Building Docker image..."
docker build -t travel-analytics:latest ..

# Apply Kubernetes manifests
echo "☸️  Deploying to Kubernetes..."
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/travel-api-deployment

# Get service URL
echo "📡 Service URL:"
minikube service travel-api-service --url

echo "✅ Deployment complete!"
