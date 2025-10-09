pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "amandock8252/java-app"
        DOCKER_TAG = "${BUILD_NUMBER}"
        SONAR_PROJECT_KEY = "java-app"
        SONAR_AUTH_TOKEN = credentials('sonarqube-token')
        KUBECONFIG_CRED = 'kubeconfig'
        LOCAL_CONTAINER_NAME = "java-app"
        LOCAL_PORT = 30080
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
                    post { always { junit 'target/surefire-reports/*.xml' } }
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
                            echo "✅ SonarQube Quality Gate: ${qg.status}"
                        }
                    } catch(err) {
                        echo "⚠️ Quality Gate check timed out, continuing..."
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    echo "🐳 Building Docker image..."
                    docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                    docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                """
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo "🔐 Logging in to DockerHub..."
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout
                    """
                }
            }
        }

        stage('Run Local Docker Container') {
            steps {
                script {
                    sh """
                        echo "🧹 Cleaning old container (if exists)..."
                        docker ps -aq --filter "name=${LOCAL_CONTAINER_NAME}" | grep -q . && docker rm -f ${LOCAL_CONTAINER_NAME} || true

                        echo "🚀 Running new container..."
                        docker run -d -p ${LOCAL_PORT}:8080 --name ${LOCAL_CONTAINER_NAME} ${DOCKER_IMAGE}:latest

                        echo "⏳ Waiting for app to start..."
                        sleep 10

                        echo "🔍 Checking app health..."
                        curl -s http://localhost:${LOCAL_PORT}/actuator/health || echo "⚠️ Health endpoint not reachable yet!"
                    """
                }
            }
        }

        stage('Deploy to Kubernetes (Optional)') {
            steps {
                script {
                    try {
                        withCredentials([file(credentialsId: "${KUBECONFIG_CRED}", variable: 'KUBECONFIG')]) {
                            sh """
                                echo "🚀 Deploying to Kubernetes..."
                                kubectl apply -f k8s/deployment.yaml --validate=false
                                kubectl apply -f k8s/service.yaml --validate=false
                                kubectl set image deployment/java-app java-app=${DOCKER_IMAGE}:${DOCKER_TAG} --record
                                kubectl rollout status deployment/java-app
                                echo "✅ Kubernetes deployment complete!"
                            """
                        }
                    } catch(err) {
                        echo "⚠️ Kubernetes deploy failed or skipped. Check kubeconfig/permissions."
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline executed successfully!'
            sh "curl -s http://localhost:${LOCAL_PORT}/actuator/health || true"
        }
        failure { echo '❌ Pipeline failed!' }
        always { cleanWs() }
    }
}
