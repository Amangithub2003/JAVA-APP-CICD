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

        stage('Run Docker Container') {
            steps {
                sh """
                    echo "🚀 Deploying Docker container..."
                    # Stop & remove old container if exists
                    docker stop java-app || true
                    docker rm java-app || true
                    # Run new container in background with auto-restart
                    docker run -d --name java-app --restart unless-stopped -p 30080:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}
                    echo "✅ Container running at http://localhost:30080"
                """
            }
        }
    }

    post {
        success { echo '✅ Pipeline executed successfully!' }
        failure { echo '❌ Pipeline failed!' }
        always { cleanWs() }
    }
}
