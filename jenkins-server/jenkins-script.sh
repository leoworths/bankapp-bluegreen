#!bin/bash
sudo apt update 
sudo apt install -y curl wget apt-transport-https ca-certificates software-properties-common

#install java 17
sudo apt install -y openjdk-17-jre-headless
#sudo apt install -y temurin-17-jdk


#install jenkins

sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update 
sudo apt-get install jenkins -y

sudo systemctl enable jenkins
sudo systemctl start jenkins


#install docker
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y


# Add jenkins to docker group
sudo usermod -aG docker ubuntu
newgrp docker
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
sudo systemctl enable docker

#install gitleaks
sudo apt-get install gitleaks -y

#install trivy
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy -y

#install kubectl
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

#install helm
sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
sudo ./get_helm.sh

#install awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
sudo unzip awscliv2.zip
sudo ./aws/install

#install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
sudo chmod +x /usr/local/bin/eksctl

#run sonarqube on docker
sudo docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
#run nexus on docker
#sudo docker run -d --name nexus -p 8081:8081 sonatype/nexus3

# Capture URLs and Credentials for SonarQube
SONARQUBE_URL="http://$(curl -s ifconfig.me):9000"
SONARQUBE_USERNAME="admin"
SONARQUBE_PASSWORD="admin"

# Capture URLs and Credentials for Nexus
NEXUS_URL="http://$(curl -s ifconfig.me):8081"
NEXUS_USERNAME="admin"
NEXUS_PASSWORD=$(sudo docker exec nexus cat /sonatype-work/nexus3/admin.password)

# Capture Jenkins URL and Credentials
JENKINS_URL="http://$(curl -s ifconfig.me):8080"
JENKINS_USERNAME="admin"
JENKINS_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)

# Print URLs and Credentials 
echo "------------------------------------------------------------"
echo "SonarQube URL: $SONARQUBE_URL"
echo "SonarQube Username: $SONARQUBE_USERNAME"
echo "SonarQube Password: $SONARQUBE_PASSWORD"
echo "------------------------------------------------------------"
echo "Nexus URL: $NEXUS_URL"
echo "Nexus Username: $NEXUS_USERNAME"
echo "Nexus Password: $NEXUS_PASSWORD"
echo "------------------------------------------------------------"
echo "Jenkins URL: $JENKINS_URL"
echo "Jenkins Username: $JENKINS_USERNAME"
echo "Jenkins Password: $JENKINS_PASSWORD"
echo "------------------------------------------------------------"
