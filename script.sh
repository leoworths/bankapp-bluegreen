#install sonarqube to run on docker
sudo docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
#get sonarqube public ip
echo "Sonarqube url is http://$(curl -s ifconfig.me):9000"
#get sonarqube username and password
echo "Sonarqube username is admin"
echo "Sonarqube password is admin"

#install nexus to run on docker
sudo docker run -d --name nexus -p 8081:8081 sonatype/nexus3
#get nexus url 
echo "Nexus url is http://$(curl -s ifconfig.me):8081"
#get nexus username and password
echo "Nexus username is admin"
echo "Nexus password is $(sudo docker exec -it nexus cat /sonatype-work/nexus3/admin.password)"

#get jenkins public ip
echo "Jenkins url is http://$(curl -s ifconfig.me):8080"
#get jenkins username and password
echo "Jenkins username is admin"
echo "Jenkins password is $(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"


#command to run script
#vi script.sh
#chmod +x script.sh
#./script.sh

sudo cat /var/log/cloud-init-output.log

#to get nexus password
docker exec -it container-name /bin/bash
ls 
cd /sonatype-work/nexus3
cat admin.password

