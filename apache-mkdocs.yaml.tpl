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
  - python3
  - python3-pip
  - postgresql-client
  - libapache2-mod-php
  - awscli
  - mkdocs
  - git
  - curl
  - wget

runcmd:
  # --- MKDocs / Apache setup ---
  - mkdir -p /home/spiderman/mkdocs
  - cd /home/spiderman/mkdocs
  - mkdocs new mkdocs-project
  - cd mkdocs-project
  - mkdocs build
  - rm /var/www/html/index.html || true
  - cp -R site/* /var/www/html
  - mv /var/www/html/index.html /var/www/html/index1.html || true
  - aws s3 cp s3://alexrachok-terraform-web-site-static-content/index.html /var/www/html/index.html
  - aws s3 cp s3://alexrachok-terraform-web-site-static-content/web_site2/index.php /var/www/html/index.php
  - systemctl restart apache2

  # --- PostgreSQL setup ---
  - sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  - wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
  - apt update
  - DEBIAN_FRONTEND=noninteractive apt install -y postgresql-client-17

  # --- Python deps for crypto updater ---
  - pip3 install --no-cache-dir psycopg2-binary requests

  # --- Crypto updater setup ---
  - mkdir -p /opt/crypto_updater
  - aws s3 cp s3://alexrachok-terraform-web-site-static-content/web_site2/crypto_updater.py /opt/crypto_updater/crypto_updater.py
  - chmod +x /opt/crypto_updater/crypto_updater.py

  # --- Database restore (optional) ---
  - aws s3 cp s3://alexrachok-terraform-web-site-static-content/web_site2/db_backup.dump /tmp/db.sql.dump
  - PGPASSWORD='${db_password}' psql -h ${db_host} -U ${db_user} -d postgres -c "CREATE DATABASE ${db_name};" || true
  - PGPASSWORD='${db_password}' psql -h ${db_host} -U ${db_user} -d postgres -f /tmp/db.sql.dump || true

  # --- Systemd service for crypto updater ---
  - |
    tee /etc/systemd/system/crypto_updater.service > /dev/null << 'EOF'
    [Unit]
    Description=Crypto Rates Updater
    After=network.target

    [Service]
    Type=simple
    User=spiderman
    WorkingDirectory=/opt/crypto_updater
    ExecStart=/usr/bin/python3 /opt/crypto_updater/crypto_updater.py
    Restart=always
    RestartSec=5
    Environment="DB_HOST=${db_host}"
    Environment="DB_PORT=5432"
    Environment="DB_NAME=${db_name}"
    Environment="DB_USER=${db_user}"
    Environment="DB_PASS=${db_password}"
    Environment="PYTHONUNBUFFERED=1"

    [Install]
    WantedBy=multi-user.target
    EOF

  - systemctl daemon-reload
  - systemctl enable crypto_updater.service
  - systemctl start crypto_updater.service
