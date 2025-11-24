#cloud-config-mkdocs-system

groups:
  - ubuntu: [root,sys]
  - dpro42-group

users:
  - default
  - name: spiderman
    gecos: Peter Parker
    shell: /bin/bash
    primary_group: dpro42-group
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    lock_passwd: false
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8bJfR85v9E+M096iS8Tn5eqOD3BpjezKfbASwNA8Um azuread\aliaksandrrachok@EPGETBIW0398

packages:
  - apache2
  - php
  - php-pgsql


runcmd:
  - touch /home/spiderman/hello.txt
  - echo "Hello! and welcome to this server! Destroy me when you are done!" >> /home/spiderman/hello.txt
  - sudo apt-get update -y
  - sudo apt install apache2 -q -y
  ## 4/1/2025: replaced pip install of mkdocs with apt-get install
  # old - sudo apt install python3-pip -y
  # old - sudo pip install mkdocs
  - sudo apt-get install mkdocs -q -y
  - sudo apt install awscli -q -y
  - sudo mkdir /home/spiderman/mkdocs
  - cd /home/spiderman/mkdocs
  - sudo mkdocs new mkdocs-project
  - cd mkdocs-project
  - sudo mkdocs build
  - sudo rm /var/www/html/index.html
  - sudo cp -R site/* /var/www/html
  - sudo mv /var/www/html/index.html /var/www/html/index1.html
  - sudo aws s3 cp s3://alexrachok-terraform-web-site-static-content/index.html /var/www/html/index.html
  - sudo aws s3 cp s3://alexrachok-terraform-web-site-static-content/web_site2/index.php /var/www/html/index.php
  - sudo apt install -y postgresql-client php php-pgsql
  - sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  - wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  - sudo apt update
  - sudo DEBIAN_FRONTEND=noninteractive apt install -y postgresql-client-17
  - sudo apt-get install -y python3 python3-pip
  - sudo pip3 install psycopg2-binary requests
  - sudo apt install libapache2-mod-php -y
  - sudo mkdir -p /opt/crypto_updater
  - sudo aws s3 cp s3://alexrachok-terraform-web-site-static-content/web_site2/crypto_updater.py /opt/crypto_updater/crypto_updater.py
  - sudo chmod +x /opt/crypto_updater/crypto_updater.py

  - sudo aws s3 cp s3://alexrachok-terraform-web-site-static-content/web_site2/db_backup.dump /tmp/db.sql.dump


  - sudo PGPASSWORD='${db_password}' psql -h ${db_host} -U ${db_user} -d postgres -c "CREATE DATABASE ${db_name};"
  - sudo PGPASSWORD='${db_password}' psql -h ${db_host} -U ${db_user} -d postgres -f /tmp/db.sql.dump


  - sudo systemctl restart apache2

  


  