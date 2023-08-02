## Script Description
A bash script, which install checks if **docker** and **docker-compose** is installed on the system and if not then it will install both the packages and will be able to create a **WordPress** site of latest WordPress Version.

### How to use

* NOTE: Script needs sudo privileges to execute properly

```bash
#commands 

# to create a site
sudo ./dc-wp-create.sh SITE_NAME 

# to disable/enable site
sudo ./dc-wp-create.sh SITE_NAME disable 
sudo ./dc-wp-create.sh SITE_NAME enable

# to delete site
sudo ./dc-wp-create.sh SITE_NAME delete


example: 

sudo ./dc-wp-create.sh hirtcamp.local 


```


