echo "********************************* Prerequisite **************************************"
yum install vim wget -y
con=`nmcli connection show | grep ethernet | awk '{print $1}'`
nmcli connection modify $con connection.autoconnect yes
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
cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
gpgcheck=1
repo_gpgcheck=1
enabled=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg https://packages.cloud.google.com/yum/doc/yum-key.gpg
EOF
yum clean all -y
yum repolist all -y
yum install kubectl kubelet kubeadm -y
systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet


echo "********************************* CRI-O INSTALLATION **************************************"
curl -L -o /etc/yum.repos.d/libcontainers-stable.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/CentOS_7/devel:kubic:libcontainers:stable.repo

curl -L -o /etc/yum.repos.d/crio.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:1.21/CentOS_7/devel:kubic:libcontainers:stable:cri-o:1.21.repo

yum install cri-o -y
systemctl start crio
systemctl enable crio


echo "********************************* Initialize Kubernetes **************************************"

kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
wget -O /root/calico.yaml https://docs.projectcalico.org/manifests/calico.yaml --no-check-certificate
vim -c "%s/docker.io/quay.io/g" -c "wq" /root/calico.yaml
kubectl apply -f /root/calico.yaml


echo "COPY JOIN COMMAND AND PASTE ON WORKER NODES"
