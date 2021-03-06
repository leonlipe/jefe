#!/bin/bash
#
# wordpress jefe-cli.sh

# Load utilities
source ~/.jefe-cli/libs/utilities.sh

# load container names vars
load_containers_names(){
    VOLUME_DATABASE_CONTAINER_NAME="${project_name}_db_data"
    DATABASE_CONTAINER_NAME="${project_name}_db"
    APP_CONTAINER_NAME="${project_name}_wordpress"
}

# Configure environments vars of docker.
docker_env() {
    puts "Docker compose var env configuration." BLUE
    echo "" > .jefe/.env
    set_dotenv PROJECT_TYPE $project_type
    puts "Write project name (default $project_type):" MAGENTA
    read proyect_name
    if [ -z $proyect_name ]; then
        set_dotenv PROJECT_NAME $project_type
        proyect_name=$project_type
    else
        set_dotenv PROJECT_NAME $proyect_name
    fi
    puts "Write project root, directory path from your proyect (default src):" MAGENTA
    read option
    if [ -z $option ]; then
        set_dotenv PROJECT_ROOT "../src/"
    else
        set_dotenv PROJECT_ROOT "../${option}/"
    fi
    puts "Write vhost (default $proyect_name.local):" MAGENTA
    read option
    if [ -z $option ]; then
        set_dotenv VHOST "$proyect_name.local"
    else
        set_dotenv VHOST $option
    fi
    puts "Write environment var name, (default development):" MAGENTA
    read option
    if [ -z $option ]; then
        set_dotenv ENVIRONMENT "development"
    else
        set_dotenv ENVIRONMENT "$option"
    fi
    puts "Write wordpress version, (default latest):" MAGENTA
    read option
    if [ -z $option ]; then
        set_dotenv WORDPRESS_VERSION "latest"
    else
        set_dotenv WORDPRESS_VERSION "$option"
    fi
    puts "Write wordpress table prefix (default wp_):" MAGENTA
    read option
    if [ -z $option ]; then
        set_dotenv WORDPRESS_TABLE_PREFIX "wp_"
    else
        set_dotenv WORDPRESS_TABLE_PREFIX $option
    fi

    puts "Database root password is password" YELLOW
    set_dotenv DB_ROOT_PASSWORD "password"
    puts "Database name is wordpress" YELLOW
    set_dotenv DB_NAME "wordpress"
    puts "Database user is wordpress" YELLOW
    set_dotenv DB_USER "wordpress"
    puts "Database wordpress password is wordpress" YELLOW
    set_dotenv DB_PASSWORD "wordpress"
    puts "phpMyAdmin url: phpmyadmin.$vhost" YELLOW
}

# Fix permisions of the proyect folder
after_up(){
    puts "Setting permissions..." BLUE
    if id "www-data" >/dev/null 2>&1; then
        docker exec -it "$APP_CONTAINER_NAME" bash -c 'chgrp www-data -R .'
    fi
    puts "Done." GREEN
}


# Create dump of the database of the proyect.
dump() {
    usage= cat <<EOF
dump [-e] [--environment] [-f] [--file] [-h] [--help]

Arguments:
    -e, --environment		Set environment to import dump. Default is docker
    -f, --file			File name of dump. Default is dump.sql
    -h, --help			Print Help (this message) and exit
EOF
    # set an initial value for the flag
    ENVIRONMENT="docker"
    FILE_NAME="dump.sql"

    # read the options
    OPTS=`getopt -o e:f:h --long environment:,file:,help -n 'jefe' -- "$@"`
    if [ $? != 0 ]; then puts "Invalid options." RED; exit 1; fi
    eval set -- "$OPTS"

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
            -e|--environment) ENVIRONMENT=$2 ; shift 2 ;;
            -f|--file) FILE_NAME=$2 ; shift 2 ;;
            -h|--help) echo $usage ; exit 1 ; shift ;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    if [[ "$ENVIRONMENT" == "docker" ]]; then
        docker exec -i ${project_name}_db mysqldump -u ${dbuser} -p"${dbpassword}" ${dbname}  > "./dumps/${FILE_NAME}"
    else
        load_settings_env $ENVIRONMENT
        ssh ${user}@${host} "mysqldump -u${dbuser} -p\"${dbpassword}\" ${dbname} --host=${dbhost} > ./dumps/${FILE_NAME}"
    fi
}

# Import dump of dumps folder of the proyect.
import_dump() {
    usage= cat <<EOF
import_dump [-f] [--file] [-h] [--help]

Arguments:
    -f, --file			File name of dump to import. Defualt is dump.sql
    -h, --help			Print Help (this message) and exit
EOF
    # set an initial value for the flag
    ENVIRONMENT="docker"
    FILE_NAME="dump.sql"

    # read the options
    OPTS=`getopt -o e:f:h --long environment:,file:,help -n 'jefe' -- "$@"`
    if [ $? != 0 ]; then puts "Invalid options." RED; exit 1; fi
    eval set -- "$OPTS"

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
            -e|--environment) ENVIRONMENT=$2 ; shift 2 ;;
            -f|--file) FILE_NAME=$2 ; shift 2 ;;
            -h|--help) echo $usage ; exit 1 ; shift ;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    docker exec -i ${project_name}_db mysql -u ${dbuser} -p"${dbpassword}" ${dbname}  < "./dumps/${FILE_NAME}"
    set_siteurl

}

# Delete database and create empty database.
resetdb() {
    usage= cat <<EOF
resetdb [-e] [--environment] [-h] [--help]

Arguments:
    -e, --environment		Set environment to import dump. Default is docker
    -h, --help			Print Help (this message) and exit
EOF
    # set an initial value for the flag
    ENVIRONMENT="docker"

    # read the options
    OPTS=`getopt -o e:h --long environment:,help -n 'jefe' -- "$@"`
    if [ $? != 0 ]; then puts "Invalid options." RED; exit 1; fi
    eval set -- "$OPTS"

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
            -e|--environment) ENVIRONMENT=$2 ; shift 2 ;;
            -h|--help) echo $usage ; exit 1 ; shift ;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    if [[ "$ENVIRONMENT" == "docker" ]]; then
        docker exec -i ${project_name}_db mysql -u"${dbuser}" -p"${dbpassword}" -e "DROP DATABASE IF EXISTS ${dbname}; CREATE DATABASE ${dbname}"
    else
        load_settings_env $ENVIRONMENT
        ssh ${user}@${host} "mysql -u${dbuser} -p\"${dbpassword}\" ${dbname} --host=${dbhost} -e \"DROP DATABASE IF EXISTS ${dbname}; CREATE DATABASE ${dbname}\""
    fi
}

# Update siteurl and home options value in wordpress database.
set_siteurl() {
    usage= cat <<EOF
set_siteurl [-e] [--environment] [-H] [--host] [-h] [--help]

Arguments:
    -e, --environment		Set environment to import dump. Default is docker
    -H, --host			Host to set. Defualt value of the VHOST configured
    -h, --help			Print Help (this message) and exit
EOF
    # set an initial value for the flag
    ENVIRONMENT="docker"
    HOST="$VHOST"

    # read the options
    OPTS=`getopt -o e:H:h --long environment:,host:,help -n 'jefe' -- "$@"`
    if [ $? != 0 ]; then puts "Invalid options." RED; exit 1; fi
    eval set -- "$OPTS"

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
            -e|--environment) ENVIRONMENT=$2 ; shift 2 ;;
            -H|--host) HOST=$2 ; shift 2 ;;
            -h|--help) echo $usage ; exit 1 ; shift ;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    WORDPRESS_TABLE_PREFIX=$( get_dotenv "WORDPRESS_TABLE_PREFIX" )
    if [[ "$ENVIRONMENT" == "docker" ]]; then
        docker exec -i ${project_name}_db mysql -u ${dbuser} -p"${dbpassword}" ${dbname} -e "UPDATE ${WORDPRESS_TABLE_PREFIX}options SET option_value='http://${HOST}' WHERE option_name like 'siteurl'"
        docker exec -i ${project_name}_db mysql -u ${dbuser} -p"${dbpassword}" ${dbname} -e "UPDATE ${WORDPRESS_TABLE_PREFIX}options SET option_value='http://${HOST}' WHERE option_name like 'home'"
    else
        load_settings_env $ENVIRONMENT
        ssh ${user}@${host} "mysql -u${dbuser} -p\"${dbpassword}\" ${dbname} --host=${dbhost} < ./dumps/${FILE_NAME}"
    fi
}

# Synchronize files to the selected environment.
deploy() {
    usage= cat <<EOF
ps [-e <environment>] [--environment <environment>] [-t] [--test] [-h] [--help]

Arguments:
    -e, --environment		Set environment to deployed
    -t, --test			Perform a test of the files to be synchronized
    -h, --help			Print Help (this message) and exit
EOF
    # set an initial value for the flag
    ENVIRONMENT=""
    TEST=false

    # read the options
    OPTS=`getopt -o e:th --long environment:,test,help -n 'jefe' -- "$@"`
    if [ $? != 0 ]; then puts "Invalid options." RED; exit 1; fi
    eval set -- "$OPTS"

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
            -e|--environment) ENVIRONMENT=$2 ; shift 2 ;;
            -t|--test) TEST=true ; shift ;;
            -h|--help) echo $usage ; exit 1 ; shift ;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    load_settings_env $ENVIRONMENT
    excludes=$( echo $exclude | sed -e "s/;/ --exclude=/g" )
    cd .jefe
    if $TEST; then
        puts "Synchronizing themes" BLUE
        set -v #verbose on
        rsync --dry-run -az --force --delete --progress --exclude=$excludes -e "ssh -p${port}" "${project_root}themes/." "${user}@${host}:${public_dir}themes/"
        set +v #verbose off
        puts "Done." GREEN

        puts "Synchronizing plugins" BLUE
        set -x #verbose on
        rsync --dry-run -az --force --delete --progress --exclude=$excludes -e "ssh -p${port}" "${project_root}plugins/." "${user}@${host}:${public_dir}plugins/"
        set +v #verbose off
        puts "Done." GREEN
    else
        puts "Synchronizing themes" BLUE
        set -x #verbose on
        rsync -az --force --delete --progress --exclude=$excludes -e "ssh -p$port" "${project_root}themes/." "${user}@${host}:${public_dir}themes/"
        set +x #verbose off
        puts "Done." GREEN

        puts "Synchronizing plugins" BLUE
        set -x #verbose on
        rsync -az --force --delete --progress --exclude=$excludes -e "ssh -p$port" "${project_root}plugins/." "${user}@${host}:${public_dir}plugins/"
        set +x #verbose off
        puts "Done." GREEN
    fi
    cd ..
}

# Execute the command "composer install" in workdir folder.
composer_install() {
    e=$1
    if [ -z "${e}" ]; then
        e="docker"
    fi
    if [[ "$e" == "docker" ]]; then
        docker exec -it ${project_name}_php bash -c 'composer install'
    else
        load_settings_env $e
        ssh ${user}@${host} -p $port "cd ${public_dir}/; composer install"
    fi
}

# Execute the command "composer update" in workdir folder.
composer_update() {
    e=$1
    if [ -z "${e}" ]; then
        e="docker"
    fi
    if [[ "$e" == "docker" ]]; then
        docker exec -it ${project_name}_php bash -c 'composer update'
    else
        load_settings_env $e
        ssh ${user}@${host} -p $port "cd ${public_dir}/; composer update"
    fi
}

# Define wordpress debug to true or false.
debug(){
    usage= cat <<EOF
debug [true] [false] [-h] [--help]

Arguments:
    false			Define wordpress debug to false
    true			Define wordpress debug to true
    -h, --help			Print Help (this message) and exit
EOF
    # set an initial value for the flag
    DEBUG=false

    # read the options
    OPTS=`getopt -o h --long help -n 'jefe' -- "$@"`
    if [ $? != 0 ]; then puts "Invalid options." RED; exit 1; fi
    eval set -- "$OPTS"

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
            -h|--help) echo $usage ; exit 1 ; shift ;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    if [[ true == "$1" ]]; then
        DEBUG=true
    fi
    puts "Setting wordpress debug..."
    docker exec -it $APP_CONTAINER_NAME bash -c "sed -i \"s/define('WP_DEBUG', .*);/define('WP_DEBUG', $DEBUG);/g\" wp-config.php"
}

php-extensions-install() {
    docker exec -it $APP_CONTAINER_NAME bash -c "
        apt-get update && \
        apt-get install -y libfreetype6-dev libjpeg62-turbo-dev libmcrypt-dev  curl git && \
        rm -rf /var/lib/apt/lists/* && \
        docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/  &&  \
        docker-php-ext-install intl && \
        docker-php-ext-install gd && \
        docker-php-ext-install zip && \
        docker-php-ext-install mcrypt && \
        docker-php-ext-install pdo_mysql
    "
    # Install composer
    docker exec -it $APP_CONTAINER_NAME bash -c "
        php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && \
        php -r \"if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;\" && \
        php composer-setup.php && \
        php -r \"unlink('composer-setup.php');\" && \
        mv composer.phar /usr/local/bin/composer
    "
    # Install composer
    docker exec -it $APP_CONTAINER_NAME bash -c " echo '
log_errors = On
error_log = /dev/stderr
short_open_tag=On
max_execution_timen = 3000
max_input_time = 3000
memory_limit = 1000
post_max_size = 100M
upload_max_filesize = 100M
' > /usr/local/etc/php/conf.d/php.ini
    "
#     docker exec -it $APP_CONTAINER_NAME bash -c "apt-get update && apt-get install -y zlib1g-dev && rm -rf /var/lib/apt/lists/* && docker-php-ext-install zip"
}

# Initialice
load_containers_names
