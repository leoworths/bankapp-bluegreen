pipeline {
    agent any
    tools {
        jdk 'jdk21'
        maven 'maven'
    }
    environment {
        IMAGE_NAME = "leoworths/bankapp"
        SCANNER_HOME= tool 'sonar-scanner'
        VERSION_TAG= "v1.0.${env.BUILD_NUMBER}"
    }
    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/leoworths/bankapp-bluegreen.git'
            }
        }
        stage('Compile & Test') {
            steps {
                sh "mvn compile"
                sh "mvn test -DskipTests"
            }
        }
        stage('Gitleaks Scan') {
            steps {
                sh "gitleaks detect --source . -r gitleaks-report.json -f json || true"
            }
        }
        stage('Trivy File Scan') {
            steps {
                sh "trivy fs --format table -o fs.html ."
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh "$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=bankapp -Dsonar.projectName=bankapp -Dsonar.java.binaries=target"
                }
            }
        }
        stage('Quality Gate Check') {
            steps {
                script{
                    timeout(time: 5, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
                    }
                }
            }
        }
        stage('OWASP Dependencies Check'){
            steps{
                dependencyCheck additionalArguments: '--scan ./target --format ALL', odcInstallation: 'owasp'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('Build & Package'){
            steps {
                sh "mvn package -DskipTests"
            }
        }
        stage('Docker Build & Tag Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {
                        sh "docker build -t ${IMAGE_NAME}:${VERSION_TAG} ."
                    }
                }
            }
        }
        stage('Trivy Image Scan') {
            steps {
                sh "trivy image --format table -o image.html ${IMAGE_NAME}:${VERSION_TAG}"
            }
        }
        stage('Docker Push Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {
                        sh "docker push ${IMAGE_NAME}:${VERSION_TAG}"
                    }
                }
            }
        }
        stage('Update Kubernetes Manifest in Git') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'git-cred', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD')]) {
                        sh "git clone https://$GIT_USERNAME:$GIT_PASSWORD@github.com/leoworths/bankapp-bluegreen.git"
                        dir ("bankapp-bluegreen") {
                        sh "sed -i 's|image:.*|image: ${IMAGE_NAME}:${VERSION_TAG}|g' k8s/rollout.yaml"
                        sh "git config --global user.email 'leoworths@gmail.com'"
                        sh "git config --global user.name 'leoworths'"
                        sh "git add k8s/rollout.yaml"
                        sh "git commit -m 'Update image tag to ${VERSION_TAG}'"
                        sh "git push origin main"
                        }
                    }
                }
            }
        }
        stage('CleanUP Docker Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker rmi ${IMAGE_NAME}:${VERSION_TAG}"
                    }
                }
            }
        }
    }
    post{
        always{
            emailext (
                attachLog: true,
                subject: "Build ${currentBuild.result}",
                body: """Project: ${env.JOB_NAME}<br/>" +
                    "Build Number: ${env.BUILD_NUMBER}<br/>" +
                    "URL: ${env.BUILD_URL}<br/>""",
                to: "leoworths@gmail.com",
                attachmentsPattern: "fs.html, image.html"
            )
        }
    }
}

    