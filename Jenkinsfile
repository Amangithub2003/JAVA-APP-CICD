pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "amandock8252/java-app"
        DOCKER_TAG = "${BUILD_NUMBER}"
        SONAR_PROJECT_KEY = "java-app"
        SONAR_AUTH_TOKEN = credentials('sonarqube-token')
    }
    
    tools {
        maven 'Maven-3.9'
        jdk 'JDK-17'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', 
                    url: 'https://github.com/Amangithub2003/JAVA-APP-CICD.git'
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        mvn sonar:sonar \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                        -Dsonar.host.url=http://localhost:9000 \
                        -Dsonar.login=${SONAR_AUTH_TOKEN}
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }

        stage('Image Scanning - Trivy') {
            steps {
                sh '''
                    # Install Trivy if not exists
                    if ! command -v trivy &> /dev/null; then
                        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
                        sudo apt-get update
                        sudo apt-get install trivy -y
                    fi
                    
                    # Scan image for HIGH and CRITICAL vulnerabilities
                    trivy image --severity HIGH,CRITICAL ${DOCKER_IMAGE}:${DOCKER_TAG}
                '''
            }
        }

        stage('Push to DockerHub') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                        docker.image("${DOCKER_IMAGE}:${DOCKER_TAG}").push()
                        docker.image("${DOCKER_IMAGE}:latest").push()
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    sh '''
                        # Update image tag in deployment manifest
                        sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" k8s/deployment.yaml
                        
                        # Apply Kubernetes manifests
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml
                        
                        # Wait for deployment rollout
                        kubectl rollout status deployment/java-app
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline executed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
        always {
            cleanWs()
        }
    }
}
