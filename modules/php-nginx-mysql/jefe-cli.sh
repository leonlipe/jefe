#!/bin/bash
#
# php-nginx-mysql jefe-cli.sh
#

# load container names vars
load_containers_names(){
    VOLUME_DATABASE_CONTAINER_NAME="${project_name}_db_data"
    DATABASE_CONTAINER_NAME="${project_name}_mysql"
    APP_CONTAINER_NAME="${project_name}_php"
    NGINX_CONTAINER_NAME="${project_name}_nginx"
}

# Docker compose var env configuration.
docker_env() {
    puts "Docker compose var env configuration." BLUE
    #     if [[ ! -f "$PROYECT_DIR/.env" ]]; then
    #         cp $PROYECT_DIR/default.env $PROYECT_DIR/.env
    #     fi
    echo "" > $PROYECT_DIR/.env
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
        set_dotenv PROJECT_ROOT "../src"
    else
        set_dotenv PROJECT_ROOT "../$option"
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
    puts "Write database name (default $proyect_name):" MAGENTA
    read option
    if [ -z $option ]; then
        set_dotenv DB_NAME "$proyect_name"
    else
        set_dotenv DB_NAME $option
    fi
    puts "Write database username (default $proyect_name):" MAGENTA
    read option
    if [ -z $option ]; then
        set_dotenv DB_USER "$proyect_name"
    else
        set_dotenv DB_USER $option
    fi
    puts "Write database password (default password):" MAGENTA
    read option
    if [ -z $option ]; then
        set_dotenv DB_PASSWORD "password"
    else
        set_dotenv DB_PASSWORD $option
    fi
    puts "Select framework:" MAGENTA
    flag=true
    while [ $flag = true ]; do
        puts "1) None"
        puts "2) Laravel"
        puts "3) CakePHP2.x"
        puts "4) CakePH3.x"
        puts "5) Symfony"
        puts "Type the option (number) that you want(digit), followed by [ENTER]:"
        read option

        case $option in
            1)
                framework=None
                puts "Write DocumentRoot (default /var/www/html):" MAGENTA
                read option
                if [ -z $option ]; then
                    document_root='/var/www/html'
                else
                    document_root=$option
                fi
                flag=false
                ;;
            2)
                framework=Laravel
                document_root='/var/www/html'
                flag=false
                ;;
            3)
                framework=CakePHP2.x
                document_root='/var/www/html/app/webroot'
                flag=false
                ;;
            4)
                framework=CakePHP3.x
                document_root='/var/www/html/webroot'
                flag=false
                ;;
            5)
                framework=Symfony
                document_root='/var/www/html/web'
                flag=false
                ;;
            *)
                puts "Wrong option" RED
                flag=true
                ;;
        esac
    done
    set_dotenv FRAMEWORK $framework
    set_dotenv DOCUMENT_ROOT $document_root
    puts "Database root password is password" YELLOW
    set_dotenv DB_ROOT_PASSWORD "password"
}

# Fix permisions of the proyect folder
after_up(){
    puts "Setting permissions..." BLUE
    if id "www-data" >/dev/null 2>&1; then
        docker exec -it ${project_name}_php bash -c 'chgrp www-data -R .'
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
        docker exec -i $DATABASE_CONTAINER_NAME mysqldump -u ${dbuser} -p"${dbpassword}" ${dbname}  > "./dumps/${FILE_NAME}"
    fi
}

# Import dump of dumps folder of the proyect.
import_dump() {
    usage= cat <<EOF
import_dump [-e] [--environment] [-f] [--file] [-h] [--help]

Arguments:
    -e, --environment		Set environment to import dump. Default is docker
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

    if [[ "$ENVIRONMENT" == "docker" ]]; then
        docker exec -i $DATABASE_CONTAINER_NAME mysql -u ${dbuser} -p"${dbpassword}" ${dbname}  < "./dumps/${FILE_NAME}"
    fi
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
        docker exec -i ${project_name}_mysql mysql -u"${dbuser}" -p"${dbpassword}" -e "DROP DATABASE IF EXISTS ${dbname}; CREATE DATABASE ${dbname}"
    else
        load_settings_env $ENVIRONMENT
        ssh ${user}@${host} "mysql -u${dbuser} -p\"${dbpassword}\" ${dbname} --host=${dbhost} -e \"DROP DATABASE IF EXISTS ${dbname}; CREATE DATABASE ${dbname}\""
    fi
}

# Execute the command "composer install" in workdir folder
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

# Execute the command "composer update" in workdir folder
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

if [[ $FRAMEWORK == "Laravel" ]]; then
# Execute the command "php artisan migrate" in workdir folder. Running laravel migrations
migrate() {
        usage= cat <<EOF
migrate [-e] [--environment] [-f] [--force] [--refresh] [--refresh-seed] [-h] [--help]

Arguments:
    -e, --environment		Set environment to import dump. Default is docker
    -f, --force			Force Migrations to run in production (migrate
        --refresh			Roll back all of your migrations and then execute the  migrate command
        --refresh-seed			Roll back all of your migrations, execute the  migrate command and run all database seed
    -h, --help			Print Help (this message) and exit
EOF
        # set an initial value for the flag
        ENVIRONMENT="docker"
        MIGRATE_OPTION=""

        # read the options
        OPTS=`getopt -o e:fh --long environment:,force,refresh,refresh-seed,help -n 'jefe' -- "$@"`
        if [ $? != 0 ]; then puts "Invalid options." RED; exit 1; fi
        eval set -- "$OPTS"

        # extract options and their arguments into variables.
        while true ; do
            case "$1" in
                -e|--environment) ENVIRONMENT=$2 ; shift 2 ;;
                -f|--force) MIGRATE_OPTION=' --force' ; shift 2 ;;
                --refresh) MIGRATE_OPTION=':refresh' ; shift 2 ;;
                --refresh-seed) MIGRATE_OPTION=':refresh --seed' ; shift 2 ;;
                -h|--help) echo $usage ; exit 1 ; shift ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
            esac
        done

        docker exec -it ${project_name}_php bash -c "php artisan migrate${MIGRATE_OPTION}"
    }

    # Execute the command "php artisan db:seed" in workdir folder. Run all laravel database seeds
    seed() {
        docker exec -it ${project_name}_php bash -c 'php artisan db:seed'
    }
fi

if [[ $FRAMEWORK == "Symfony" ]]; then
    # Fix permisions of the proyect folder
    after_up(){
        puts "Setting permissions..." BLUE
        docker exec -it ${project_name}_php bash -c 'php symfony cc'
        docker exec -it ${project_name}_php bash -c 'php symfony permissions'
        if id "www-data" >/dev/null 2>&1; then
            docker exec -it ${project_name}_php bash -c 'chgrp www-data -R .'
        fi
        puts "Done." GREEN
    }
    migrate() {
        echo 'Command not implemented yet'
        exit 1
    }
    seed() {
        echo 'Command not implemented yet'
        exit 1
    }
fi

# Initialice
load_containers_names
