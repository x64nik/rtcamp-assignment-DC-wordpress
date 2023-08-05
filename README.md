## Script Description

A bash script, which install checks if **docker** and **docker-compose** is installed on the system and if not then it will install both the packages and will be able to create a **WordPress** site of latest WordPress Version.

* Your site name will be added to the /etc/hosts file which will be point to localhost (127.0.0.1)
* This script will pull images (mariadb, wordpress, wpcli and nginx)
* Wordpress admin panel is automatically configured with the help of **wpcli**, to chnage the default credentials please make changes into script where the **.env** contants file are define, you can even change the mariadb and wordpress db credentials  

* NOTE: if you are running this script first time, please run the script with site name, so docker and docker-compose will get installed properly


### How to use

* NOTE: Script needs sudo privileges to execute properly

```bash
#commands 

#get help
sudo ./create.sh --help

#create a site
sudo ./create.sh sitename.local

#stop containers
sudo ./create.sh stop

#start containers
sudo ./create.sh start

#delete containers
sudo ./create.sh delete

```


