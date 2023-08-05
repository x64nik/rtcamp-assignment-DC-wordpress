#!/bin/bash


docker_install() {
    echo "Updating before Installiation.."
    sudo apt-get update
    sudo apt-get install ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    echo "Adding Dockers GPG key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "Adding Docker repo"
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    echo "Updating Repo..."
    sudo apt-get update
    echo "Installing Docker"
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    
    echo "Enabling docker service.."
    sudo systemctl enable docker.service
    sudo systemctl enable containerd.service


    if ! [[ $(command -v docker) ]]
    then
        tput setaf 1; echo "Somthing went wrong, please check your system configs!"
    else
        tput setaf 2; echo "Docker is installed now!"
    fi
}

docker_compose_install() {

    sudo apt-get -y install docker-compose

    if ! [[ $(command -v docker-compose) ]]
    then
        tput setaf 1; echo "Somthing went wrong, please check your system configs!"
    else
        tput setaf 2; echo "docker-compose is installed now!"
    fi

}


check_binary() {

    echo "Checking docker..."

    if ! [[ $(command -v docker) ]]
    then
        tput setaf 1; echo "Docker not found, Installing Docker now..."
        docker_install
    else
        tput setaf 2; echo "docker is already installed"
    fi

    echo " "
    echo "Checking docker-compose..."


    if ! [[ $(command -v docker-compose) ]]
    then
        tput setaf 1; echo "docker-compose not found, Installing docker-compose now..."
        docker_compose_install
    else
        tput setaf 2; echo "docker-compose is already installed"
    fi

}

site_name_entry () {
    tput setaf 4; echo "adding sitename to hosts file"
    site_name="$1"
    sudo echo "127.0.0.1 $site_name" >> /etc/hosts
}

nginx_initial_setup() {
    mkdir -p ./configs/nginx


cat > ./configs/nginx/default.conf << EOF
server {
    listen      80;
    listen [::]:80;
    server_name localhost;

    root /var/www/html;
    index index.php;

    server_tokens off;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
EOF
    echo "Added nginx config"
}


setup_env_file() {


site_name=$1
site_title=$1

echo "creating env file for docker-compose"

cat > ./.env << EOF


# database envs

MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=wordpress
MYSQL_ROOT_PASSWORD=password

# wordpress envs

WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=wordpress
WORDPRESS_DB_NAME=wordpress

# site vars

WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=admin
WP_ADMIN_EMAIL=admin@admin.local


EOF

echo " SITE_HOSTNAME=$site_name " >> ./.env
echo " SITE_TITLE=$site_title " >> ./.env


}


create_docker_compose() {

echo "creating docker compose file...."


cat > ./docker-compose.yaml << EOF
version: "3"

services:
  db:
    image: mariadb:latest
    container_name: db
    restart: always
    environment:
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - wp-docker-01

  wordpress:
    depends_on:
      - db
    image: wordpress:php8.1-fpm-alpine
    container_name: wordpress
    restart: always
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: \${WORDPRESS_DB_USER}
      WORDPRESS_DB_PASSWORD: \${WORDPRESS_DB_PASSWORD}
      WORDPRESS_DB_NAME: \${WORDPRESS_DB_PASSWORD}
    volumes:
      - wordpress:/var/www/html
    networks:
      - wp-docker-01

  wpcli:
    depends_on:
      - db
      - wordpress
    image: wordpress:cli
    container_name: wordpress-cli
    user: 1000:1000
    environment:
        WORDPRESS_DB_HOST: db:3306
        WORDPRESS_DB_USER: wordpress
        WORDPRESS_DB_PASSWORD: wordpress
        WORDPRESS_DB_NAME: wordpress
    command:
      - /bin/bash
      - -c
      - |
        sleep 10
        wp core install --url=\${SITE_HOSTNAME} --title=\${SITE_TITLE} --admin_user=\${WP_ADMIN_USER} --admin_password=\${WP_ADMIN_PASSWORD} --admin_email=\${WP_ADMIN_EMAIL} --skip-email
    volumes:
      - wordpress:/var/www/html
    networks:
      - wp-docker-01

  nginx:
    depends_on:
      - wordpress
      - db
    image: nginx:latest
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - wordpress:/var/www/html
      - ./configs/nginx/default.conf:/etc/nginx/conf.d/default.conf
    networks:
      - wp-docker-01

volumes:
  wordpress:
  db_data:
networks:
  wp-docker-01:
EOF

tput setaf 2; echo "docker file created!"


}


create_lemp_wp() {


    docker-compose up -d

    tput setaf 2; echo "Container Created!"
    tput setaf 3; echo "Waiting for db to start..."
    sleep 10;
    tput setaf 10; echo "Your site $site_name up and running."
    tput setaf 3; echo "Click here to visit: http://$site_name"

}


start_site() {

    docker-compose start
    tput setaf 2; echo "Containers Started!"
}

stop_site() {
    docker-compose stop
    tput setaf 1; echo "Containers Stopped!"
}

delete_site() {



    tput setaf 1; echo "Removing containers..."
    docker-compose down -v
    sed -i "/$site_name/d" /etc/hosts

    rm -rf ./configs
    rm -rf ./docker-compose.yaml
    rm -rf ./.env

    tput setaf 1; echo "Site Deleted!"
}



help_func() {
  echo "To create a site: sudo ./create-site.sh <sitename>"
  echo "To start/stop site containers: sudo ./create-site.sh stop/start"
  echo "To delete site: sudo ./create-site.sh delete"
}


invalid_input() {
  echo "Invaild input!"
  echo " "
  echo "If you are trying to create site please enter valid sitename"
  echo "Example: website.local"
  echo " "
  help_func
}

site_name=$1
site_title=$1
option=$2

validate="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$"

if [[ $1 == 'start' ]]
then
  start_site
  exit

elif [[ $1 == 'stop' ]]
then
  stop_site
  exit

elif [[ $1 == 'delete' ]]
then
  delete_site
  exit

elif [[ $1 == '--help' ]]
then
  help_func
  exit

elif [[  "$1" =~ $validate   ]]
then
  check_binary
  site_name_entry $site_name
  nginx_initial_setup
  setup_env_file $site_name
  create_docker_compose
  create_lemp_wp $site_name
  exit


else
  invalid_input
fi

