if [ "$1" == "" ]; then
    echo "Usage: ./gpudemo.sh <aws-instance-private-ip> <aws-instance-public-ip>"
    exit
fi
if [ "$2" == "" ]; then
    echo "Usage: ./gpudemo.sh <aws-instance-private-ip> <aws-instance-public-ip>"
    exit
fi
privateIP=$1
publicIP=$2
if [ -x "$(command -v docker)" ]; then
    docker service rm $(docker service ls -q)
    docker container rm -f $(docker container ls -aq)
    docker volume prune -f
    docker secret rm $(docker secret ls -q)
    sudo apt-get remove docker docker-engine docker-ce docker-ce-cli docker.io
fi
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
DOCKER_EE_URL="https://storebits.docker.com/ee/m/sub-7faa6023-4a29-49d5-b94a-88229b4c065e"
DOCKER_EE_VERSION=19.03
curl -fsSL "${DOCKER_EE_URL}/ubuntu/gpg" | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=$(dpkg --print-architecture)] $DOCKER_EE_URL/ubuntu \
   $(lsb_release -cs) \
   stable-$DOCKER_EE_VERSION"
sudo apt-get update
sudo apt-get install docker-ee docker-ee-cli containerd.io
sudo systemctl enable docker
docker container run --rm -it \
  --name ucp \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  docker/ucp install \
  --host-address $privateIP \
  --san $publicIP \
  --admin-username admin \
  --admin-password Password123 
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-docker2
#sudo systemctl restart docker
configJson='
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}'
sudo echo $configJson | sudo tee /etc/docker/daemon.json
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
AUTHTOKEN=$(curl -sk -d '{"username":"admin","password":"Password123"}' https://$publicIP/auth/login | jq -r .auth_token)
curl -k -H "Authorization: Bearer $AUTHTOKEN" https://$publicIP/api/clientbundle -o bundle.zip
unzip bundle.zip
eval "$(<env.sh)"
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta4/nvidia-device-plugin.yml
sudo systemctl restart docker