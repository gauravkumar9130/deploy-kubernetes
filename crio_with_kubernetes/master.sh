echo "********************************* Prerequisite **************************************"
hostnamectl set-hostname master
vim -c "g/swap/d" -c "wq" /etc/fstab
vim -c "7s/enforcing/permissive/g" -c "wq" /etc/sysconfig/selinux
swapoff -a
setenforce 0
systemctl stop firewalld
systemctl disable firewalld
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system

echo "********************************* Configure Kubernetes **************************************"
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/1.34/rpm/repodata/repomd.xml.key
EOF
yum clean all -y
yum repolist all -y
yum install kubectl kubelet kubeadm -y
systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet


echo "********************************* CRI-O INSTALLATION **************************************"
cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/1.34/rpm/repodata/repomd.xml.key
EOF
yum install cri-o -y
systemctl start crio
systemctl enable crio


echo "********************************* Initialize Kubernetes **************************************"

kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
wget -O calico.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/calico.yaml
vim -c "%s/docker.io/quay.io/g" -c "wq" /root/calico.yaml
kubectl apply -f /root/calico.yaml


echo "COPY JOIN COMMAND AND PASTE ON WORKER NODES"
