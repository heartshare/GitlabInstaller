#!/bin/sh
# USE IT: 
# apt-get -y install sudo vim curl && curl https://raw.github.com/heartshare/GitlabInstaller/master/install.sh | sudo domain_var=192.168.1.230 sh
#

if [ $domain_var ] ; then
  echo "Installing GitLab for domain: $domain_var"
else 
  echo "Please pass domain_var"
  exit
fi

echo "Host localhost
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null" | sudo tee -a /etc/ssh/ssh_config

echo "Host $domain_var
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null" | sudo tee -a /etc/ssh/ssh_config

sudo apt-get update
sudo apt-get install -y wget curl build-essential checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev zlib1g-dev libicu-dev redis-server openssh-server git-core libyaml-dev

sudo apt-get install -y python
python --version
sudo apt-get install python2.7
python2 --version
sudo ln -s /usr/bin/python /usr/bin/python2

sudo DEBIAN_FRONTEND='noninteractive' apt-get install -y postfix-policyd-spf-python postfix 


wget http://mirrors.ibiblio.org/ruby/1.9/ruby-1.9.3-p327.tar.gz
tar xfvz ruby-1.9.3-p327.tar.gz
cd ruby-1.9.3-p327
./configure
make
sudo make install
sudo gem install bundler


sudo adduser \
  --system \
  --shell /bin/sh \
  --gecos 'Git Version Control' \
  --group \
  --disabled-password \
  --home /home/git \
  git
  
  
sudo adduser --disabled-login --gecos 'GitLab' gitlab
sudo usermod -a -G git gitlab
sudo -H -u gitlab ssh-keygen -q -N '' -t rsa -f /home/gitlab/.ssh/id_rsa

cd /home/git
sudo -u git -H git clone -b gl-v304 https://github.com/gitlabhq/gitolite.git /home/git/gitolite
sudo -u git -H mkdir /home/git/bin
sudo -u git -H sh -c 'printf "%b\n%b\n" "PATH=\$PATH:/home/git/bin" "export PATH" >> /home/git/.profile'
sudo -u git -H sh -c 'gitolite/install -ln /home/git/bin'

sudo cp /home/gitlab/.ssh/id_rsa.pub /home/git/gitlab.pub
sudo chmod 0444 /home/git/gitlab.pub

sudo -u git -H sh -c "PATH=/home/git/bin:$PATH; gitolite setup -pk /home/git/gitlab.pub"

sudo chmod -R ug+rwXs /home/git/repositories/
sudo chown -R git:git /home/git/repositories/

sudo chmod 750 /home/git/.gitolite/
sudo chown -R git:git /home/git/.gitolite/


sudo -u gitlab -H git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin
sudo rm -rf /tmp/gitolite-admin


sudo apt-get install -y makepasswd
userPassword=$(makepasswd --char=10)
echo mysql-server mysql-server/root_password password $userPassword | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $userPassword | sudo debconf-set-selections
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev


cd /home/gitlab
sudo -u gitlab -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd /home/gitlab/gitlab
# Checkout v4
#sudo -u gitlab -H git checkout 4-0-stable  # default , normal in script installation 
sudo -u gitlab -H git checkout 4-2-stable
sudo -u gitlab -H cp config/gitlab.yml.example config/gitlab.yml
sudo -u gitlab -H cp config/database.yml.mysql config/database.yml
sudo sed -i 's/"secure password"/"'$userPassword'"/' /home/gitlab/gitlab/config/database.yml
sudo sed -i "s/  host: localhost/  host: $domain_var/" /home/gitlab/gitlab/config/gitlab.yml
sudo sed -i "s/ssh_host: localhost/ssh_host: $domain_var/" /home/gitlab/gitlab/config/gitlab.yml
sudo sed -i "s/notify@localhost/notify@$domain_var/" /home/gitlab/gitlab/config/gitlab.yml
sudo -u gitlab -H cp config/unicorn.rb.example config/unicorn.rb

cd /home/gitlab/gitlab

sudo gem install charlock_holmes --version '0.6.9'
sudo -u gitlab -H bundle install --deployment --without development postgres test 
sudo -u gitlab -H git config --global user.name "GitLab"
sudo -u gitlab -H git config --global user.email "gitlab@localhost"
sudo cp ./lib/hooks/post-receive /home/git/.gitolite/hooks/common/post-receive
sudo chown git:git /home/git/.gitolite/hooks/common/post-receive
sudo -u gitlab -H bundle exec rake gitlab:app:setup RAILS_ENV=production
sudo wget https://raw.github.com/gitlabhq/gitlab-recipes/4-0-stable/init.d/gitlab -P /etc/init.d/
sudo chmod +x /etc/init.d/gitlab
sudo update-rc.d gitlab defaults 21

sudo apt-get install -y nginx
sudo wget https://raw.github.com/gitlabhq/gitlab-recipes/4-0-stable/nginx/gitlab -P /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab

sudo sed -i 's/YOUR_SERVER_IP:80/80/' /etc/nginx/sites-available/gitlab
sudo sed -i "s/YOUR_SERVER_FQDN/$domain_var/" /etc/nginx/sites-available/gitlab

# Start

sudo service gitlab start
sudo service nginx start

