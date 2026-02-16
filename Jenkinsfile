//Travel Analytics - Jenkins pipeline
pipeline {
    agent any

    tools {
        python 'python3'
    }

    environment {
        PATH = "${env.PATH}:/usr/local/bin"
        APP_NAME = 'travel-analytics'
        DOCKER_IMAGE = "${APP_NAME}:${BUILD_NUMBER}"
        GITHUB_REPO = "https://github.com"
    }

    stages {
        stage('Checkout') {
            steps {
                // Fixed brackets and nesting for scmGit
                checkout scmGit(
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[url: env.GITHUB_REPO]],
                    extensions: [cleanBeforeCheckout(), cloneOption(depth: 1, shallow: true)]
                )
            }
        }

        stage('Setup Virtual Environment') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Lint') {
            steps {
                sh '''
                    . venv/bin/activate
                    pip install flake8 pylint
                    flake8 app.py --max-line-length=120 --count --statistics || true
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    . venv/bin/activate
                    mkdir -p tests
                    cat > tests/test_app.py << 'EOF'
import pytest
import sys
import os
# Assuming app.py is in the root
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_endpoint(client):
    response = client.get('/api/v1/flights')
    assert response.status_code == 200
    data = response.get_json()
    assert 'flights' in data

def test_weather_endpoint(client):
    response = client.get('/api/v1/weather/new%20york')
    data = response.get_json()
    assert response.status_code == 200
    assert data['city'] == 'New York'
EOF
                    pip install pytest
                    pytest tests/ -v --junitxml=test-results.xml
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        docker build -t ${DOCKER_IMAGE} .
                        docker tag ${DOCKER_IMAGE} ${APP_NAME}:latest
                    """
                }
            }
        }

        stage('Deploy to kubernetes') {
            when { branch 'main' }
            steps {
                script {
                    sh """
                        if command -v kubectl >/dev/null 2>&1; then
                            echo "Validating Kubernetes manifest ..."
                            kubectl apply --dry-run=client -f k8s/deployment.yaml
                            kubectl apply --dry-run=client -f k8s/service.yaml
                        else
                            echo "kubectl not found - skipping deployment"
                        fi
                    """
                }
            }
        }
    }

    post {
        always {
            sh "docker rmi ${DOCKER_IMAGE} || true"
            sh "rm -rf venv || true"
            cleanWs()
        }
        success { echo '✅ Pipeline completed successfully!' }
        failure { echo '❌ Pipeline failed - check logs' }
    }
}
