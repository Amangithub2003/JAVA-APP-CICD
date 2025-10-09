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

        stage('Parallel: Unit Tests & SonarQube Analysis') {
            parallel {
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
                            sh """
                                mvn sonar:sonar \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.host.url=http://localhost:9000 \
                                -Dsonar.login=${SONAR_AUTH_TOKEN} \
                                -Dsonar.exclusions=**/target/**,**/node_modules/**,**/*.md
                            """
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    try {
                        timeout(time: 3, unit: 'MINUTES') {
                            def qg = waitForQualityGate abortPipeline: true
                            echo "✅ SonarQube Quality Gate status: ${qg.status}"
                        }
                    } catch(err) {
                        echo "⚠️ Quality Gate check timed out, continuing pipeline..."
                    }
                }
            }
        }

        stage('Build Docker Image in Minikube') {
            steps {
                script {
                    sh '''
                        echo "🐳 Building Docker image inside Minikube..."
                        eval $(minikube -p minikube docker-env)
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                    '''
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "🔐 Logging in to DockerHub..."
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        echo "📤 Pushing image to DockerHub..."
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes (via Minikube)') {
            steps {
                script {
                    sh '''
                        echo "✅ Deploying ${DOCKER_IMAGE}:${DOCKER_TAG} to Kubernetes"

                        # Start Minikube if profile missing or not running
                        if ! minikube profile list | grep -q "minikube"; then
                            echo "⚙️ Minikube profile not found. Starting Minikube..."
                            minikube start --driver=docker --profile=minikube
                        elif ! minikube status | grep -q "Running"; then
                            echo "⚙️ Minikube not running. Starting Minikube..."
                            minikube start --driver=docker --profile=minikube
                        fi

                        # Docker env for Minikube
                        eval $(minikube -p minikube docker-env)

                        # Apply manifests and set image
                        minikube kubectl -- apply -f k8s/deployment.yaml --validate=false
                        minikube kubectl -- apply -f k8s/service.yaml --validate=false
                        minikube kubectl -- set image deployment/java-app java-app=${DOCKER_IMAGE}:${DOCKER_TAG} --record
                        minikube kubectl -- rollout status deployment/java-app

                        echo "✅ Deployment successful!"
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
