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
  - libapache2-mod-php
  - postgresql-client
  - awscli
  - git
  - curl
  - wget

runcmd:
  # --- Apache setup ---
  - rm /var/www/html/index.html || true
  - aws s3 cp s3://alexrachok-terraform-web-site-static-content/index.html /var/www/html/index.html
  - aws s3 cp s3://alexrachok-terraform-web-site-static-content/web_site2/index.php /var/www/html/index.php
  - systemctl restart apache2

  # --- PostgreSQL repository install ---
  - sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  - wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
  - apt update
  - DEBIAN_FRONTEND=noninteractive apt install -y postgresql-client-17

  # --- Database restore (optional) ---
  - aws s3 cp s3://alexrachok-terraform-web-site-static-content/web_site2/db_backup.dump /tmp/db.sql.dump || true
  - PGPASSWORD='${db_password}' psql -h ${db_host} -U ${db_user} -d postgres -c "CREATE DATABASE ${db_name};" || true
  - PGPASSWORD='${db_password}' psql -h ${db_host} -U ${db_user} -d ${db_name} -f /tmp/db.sql.dump || true

