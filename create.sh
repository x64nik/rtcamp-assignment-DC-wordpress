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

    tput setaf 5; read -p "Do you want to add user to docker group and setgid to it? (y/n) [Default: n] " option
    option="n"
    
    if [[ "$option" != "n" ]]
    then
        echo "Adding user to docker group..."
        sudo usermod -aG docker $USER
        sudo chgrp docker $(which docker)
        sudo chmod g+s $(which docker)
        echo "User added, please restart bash after script finish"
    fi
    
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
    sudo curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

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
    mkdir wp-docker
    cd wp-docker
    mkdir public nginx
    cd nginx

cat > default.conf << EOF
    events {}
    http{
        server {
            listen 80;
            server_name \$host;
            root /usr/share/nginx/html;
            index  index.php index.html index.html;

            location / {
                try_files \$uri \$uri/ /index.php?\$is_args$args;
            }

            location ~ \.php$ {
                # try_files \$uri =404;
                # fastcgi_pass unix:/run/php-fpm/www.sock;
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass phpfpm:9000;
                fastcgi_index   index.php;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                include fastcgi_params;
            }
        }
    }
EOF
    echo "Added nginx config"
    cd ..
    cd public

cat > index.php << EOF
    <?php
      echo "here";
      phpinfo();
    ?>
EOF
tput setaf 1; echo "added site"
cd ..

}

create_docker_compose() {

echo "creating docker compose file...."


cat > docker-compose.yml << EOF 
version: '3'

services:
  #databse
  db:
    image: mysql:5.7
    volumes:
      - db_data:/var/lib/mysql
    restart: always
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
      MYSQL_ROOT_PASSWORD: password
    networks:
      - wp-docker-01
  #php-fpm
  phpfpm:
    image: php:fpm
    depends_on:
      - db
    ports:
      - '9000:9000'
    volumes: ['./public:/usr/share/nginx/html']
    networks:
      - wp-docker-01
  #phpmyadmin
  phpmyadmin:
    depends_on:
      - db
    image: phpmyadmin/phpmyadmin
    restart: always
    ports:
      - '8080:80'
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: password
    networks:
      - wp-docker-01
  #wordpress
  wordpress:
    depends_on: 
      - db
    image: wordpress:latest
    restart: always
    ports:
      - '80:80'
    volumes: ['wp_data:/var/www/html']
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    networks:
      - wp-docker-01
  #nginx
  proxy:
    image: nginx:1.17.10
    depends_on:
      - db
      - wordpress
      - phpmyadmin
      - phpfpm
    ports:
      - '8001:80'
    volumes: 
      - wp_data:/var/www/html
      - ./nginx/default.conf:/etc/nginx/nginx.conf
    networks:
      - wp-docker-01


networks:
  wp-docker-01:
volumes:
  db_data:
  wp_data:
EOF

tput setaf 2; echo "docker file created!"

} 

wpcli_setup() {

  site_title=$1
  wp_container_id=$(docker ps -a | grep "wordpress:latest" | awk '{print $1}')
  docker exec $wp_container_id curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  docker exec $wp_container_id chmod u+x wp-cli.phar
  docker exec $wp_container_id mv wp-cli.phar /usr/local/bin/wp


  tput setaf 3; echo "Waiting for Mysql DB to start...."

  sleep 10
  docker exec $wp_container_id wp core install --path=/var/www/html --url=localhost --admin_user=admin --admin_password=password --admin_email=admin@admin.com --skip-email --title=$site_title --allow-root



}

create_lemp_wp() {
    pwd 
    ls
    tput setaf 1; echo "killing ports..."
    sudo fuser -k 80/tcp 8000/tcp 9000/tcp 8001/tcp 8080/tcp 
    site_name=$1
    docker-compose up -d
    tput setaf 2; echo "Container Created!"

    wpcli_setup $site_name


    tput setaf 10; echo "Your site $site_name up and running."
    tput setaf 2; echo "for local, Click here on link: http://$site_name"

    if [ "$2" == "enable" ]
    then
      docker-compose start
      tput setaf 2; echo "Containers Started!"
    elif [ "$2" == "disable" ]
    then
      docker-compose stop
      tput setaf 1; echo "Containers Stopped!"
    fi

    if [ "$2" == "delete" ]
    then
      tput setaf 1; echo "Removing containers..."
      docker-compose down -v
      sed -i "/$site_name/d" /etc/hosts
      pwd
      ls
      rm -rf ../wp-docker
      tput setaf 1; echo "Site Deleted!"
    fi

}


site_name=$1
option=$2


# LEMP STACK HERE -->
check_binary 
site_name_entry $site_name
nginx_initial_setup
create_docker_compose
create_lemp_wp $site_name $option










