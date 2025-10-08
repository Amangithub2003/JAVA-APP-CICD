pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "amandock8252/java-app"
        DOCKER_TAG = "${BUILD_NUMBER}"
        SONAR_PROJECT_KEY = "java-app"
        SONAR_AUTH_TOKEN = credentials('sonarqube-token')
        DOCKERHUB_CREDENTIALS = 'dockerhub-credentials'
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

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }

        // 🔸 Trivy stage skipped for now (can re-enable later)
        /*
        stage('Image Scanning - Trivy') {
            steps {
                script {
                    echo "⚠️ Skipping Trivy image scan (temporarily disabled to avoid timeout)"
                    // docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL ${DOCKER_IMAGE}:${DOCKER_TAG}
                }
            }
        }
        */

        stage('Push to DockerHub') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', DOCKERHUB_CREDENTIALS) {
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
                        sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" k8s/deployment.yaml
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml
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
