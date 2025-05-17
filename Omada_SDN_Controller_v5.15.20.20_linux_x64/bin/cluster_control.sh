#!/bin/bash
#
# Cluster startup script for TP-Link's Omada Controller.
#


NAME="omada"
DESC="Omada Controller"

OMADA_HOME=$(dirname $(dirname $(readlink -f $0)))
DATA_DIR="${OMADA_HOME}/data"
CLUSTER_DIR="${DATA_DIR}/cluster"
DB_DIR="${DATA_DIR}/db"
LOG_DIR="${OMADA_HOME}/logs"
MONGOD_LOG_PATH="${LOG_DIR}/mongod.log"
PROPERTY_DIR="${OMADA_HOME}/properties"
STARTUP_INFO_PATH="${DATA_DIR}/startupInfo"
MAIN_CLASS="com.tplink.smb.omada.starter.OmadaLinuxMain"

OMADA_USER=${OMADA_USER:-root}
OMADA_GROUP=$(id -gn ${OMADA_USER})
MONGODB_ORG_SHELL=mongo

CLUSTER_PROPERTIES_PATH="$2"
NODE_ID="$4"

declare -A cluster_config


help() {
    echo "Usage: $0 [<option> ...] <command>"
    cat <<EOF

Commands:
  help                                                   - this screen
  -config <properties_file> -node <node_name> init       - Initialize a specific cluster node using a specified configuration file

Options:
  -config                                                - cluster properties file
  -node                                                  - node name

EOF
}

# root permission check
check_root_perms() {
    [ $(id -ru) != 0 ] && { echo "You must be root to execute this script. Exit." 1>&2; exit 1; }
}

version_gt() {
  test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"
}

# check env
check_env() {
    if ! type mongod >/dev/null 2>&1; then
        echo "mongodb-org-server is not installed, please install it."
        exit
    fi
    # Obtain the mongoDB version and verify the mongo shell based on the mongoDB version
    MONGODB_VERSION=$(mongod -version | grep 'db version' | grep -oP '\d+\.\d+\.\d+')
    if version_gt "${MONGODB_VERSION}" "5.0.0"; then
        MONGODB_ORG_SHELL=mongosh
        if ! type ${MONGODB_ORG_SHELL} >/dev/null 2>&1; then
            echo "mongodb-mongosh is not installed, please install it."
            exit
        fi
    else
        if ! type ${MONGODB_ORG_SHELL} >/dev/null 2>&1; then
            echo "mongodb-org-shell is not installed, please install it."
            exit
        fi
    fi

    if ! type tpeap >/dev/null 2>&1; then
        echo "Omada Controller is not installed, please install it."
        exit
    fi
    [ "root" != ${OMADA_USER} ] && {
        echo "check ${OMADA_USER}"
        check_omada_user
    }
    # limit open files
    configure_omada_user
    ulimit -SHn 65535
    su ${OMADA_USER} -c "ulimit -SHn 65535"
    # Check if logs exist, if not created
    [ -e "${LOG_DIR}" ] || {
        mkdir -m 755 ${LOG_DIR} 2>/dev/null && chown -R ${OMADA_USER}:${OMADA_GROUP} ${LOG_DIR}
    }
}

# check if ${OMADA_USER} has the permission to ${DATA_DIR} ${LOG_DIR} ${WORK_DIR}
check_omada_user() {
    OMADA_UID=$(id -u ${OMADA_USER} 2>&1)
    [[ 0 != $? ]] || [[ "${OMADA_UID}" =~ "no such user" ]] && {
        echo "Failed to start ${DESC}. Please create user ${OMADA_USER} user"
        exit 1
    }

    if [ ${OMADA_UID} -ne $(stat ${DATA_DIR} -Lc %u) ]; then
        echo "Failed to start ${DESC}. Please chown -R ${OMADA_USER} ${DATA_DIR} ${LOG_DIR} ${WORK_DIR}"
        exit 1
    fi

    [ -e "${LOG_DIR}" ] && [ ${OMADA_UID} -ne $(stat ${LOG_DIR} -Lc %u) ] && {
        echo "Failed to start ${DESC}. Please chown -R ${OMADA_USER} ${LOG_DIR}"
        exit 1
    }

    [ -e "${WORK_DIR}" ] && [ ${OMADA_UID} -ne $(stat ${WORK_DIR} -Lc %u) ] && {
        echo "Failed to start ${DESC}. Please chown -R ${OMADA_USER} ${WORK_DIR}"
        exit 1
    }
}

# return: 1,running; 0, not running;
is_running() {
    [ -z "$(pgrep -f ${MAIN_CLASS})" ] && {
        return 0
    }
    return 1
}

configure_omada_user() {
    [ "root" != ${OMADA_USER} ] && {
        usermod -s /bin/bash ${OMADA_USER} > /dev/null 2>&1
    }
}

rollback_exit() {
    [ "root" != ${OMADA_USER} ] && {
        usermod -s /usr/sbin/nologin ${OMADA_USER} > /dev/null 2>&1
    }
    exit
}

# trim properties str
trimspaces() {
    echo $1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

read_cluster_properties() {
    while IFS='=' read -r prop value; do
        cluster_config[$(trimspaces $prop)]=$(trimspaces $value)
    done < <(cat ${CLUSTER_PROPERTIES_PATH} | sed -e '/^\s*$/d' -e '/^#/d')
}

ping_cluster_node() {
    echo "Check node names: ${node_ids[@]}"
    for node_id in ${node_ids[@]}
    do
        node_host_key="omada.cluster.distributed.${node_id}.host"
        node_host=${cluster_config["${node_host_key}"]}
        [ -z "${node_host}" ] && {
            echo "Node: ${node_id}, host is null."
            rollback_exit
        }
        ping -c 3 -i 0.2 -W 3 ${node_host} &> /dev/null 2>&1
        if [ $? -ne 0 ] ; then
            echo "Node: ${node_id}, Host: ${node_host}, failed to connect it."
            rollback_exit
        fi
    done

}

failover_cluster_properties_check() {
    [[ "${NODE_ID}" != "primary" && "${NODE_ID}" != "secondary" ]] && {
        echo "Invalid node id: ${NODE_ID}. Exit."
        exit
    }
    primary_host=${cluster_config["omada.cluster.hsb.primary.host"]}
    [ -z "${primary_host}" ] && {
        echo "Primary node host is null. Exit."
        exit
    }
    secondary_host=${cluster_config["omada.cluster.hsb.secondary.host"]}
    [ -z "${secondary_host}" ] && {
        echo "Secondary node host is null. Exit."
        exit
    }
    cluster_key=${cluster_config["omada.cluster.hsb.key"]}
    [ -z "${cluster_key}" ] && {
        echo "Secondary node host is null. Exit."
        exit
    }
}

horizontal_cluster_external_properties_check() {
    idstr=${cluster_config["omada.cluster.distributed.names"]}
    node_ids=(${idstr//,/})
    echo "${node_ids[@]}"
    # node id list contains input id
    if [[ ! "${node_ids[@]}" =~ "${NODE_ID}" ]] ; then
        echo "${NODE_ID} is not a cluster member (${idstr})."
        rollback_exit
    fi
    # least 3 nodes
    if [ ${#node_ids[*]} lt 3 ] ; then
        echo "The cluster requires at least 3 members."
        rollback_exit
    fi
    # name cannot be duplicated
    if [ $(echo "${node_ids[@]}" | tr ' ' '\n' | sort | uniq -d | wc -l) -ne 0 ]; then
        echo "node name cannot be duplicated."
        rollback_exit
    fi
    mongo_uri=${cluster_config["omada.cluster.distributed.mongodb.uri"]}
    [ -z "${mongo_uri}" ] && {
        echo "MongoDb URI is null. Exit."
        rollback_exit
    }
}

horizontal_cluster_properties_check() {
    idstr=${cluster_config["omada.cluster.distributed.names"]}

    # split node id
    OLD_IFS="$IFS"
    IFS=","
    node_ids=($idstr)
    IFS="$OLD_IFS"
    node_ip_array=()
    node_device_ip_array=()
    # node id list contains input id
    if [[ ! "${node_ids[@]}" =~ "${NODE_ID}" ]] ; then
        echo "${NODE_ID} is not a cluster member (${idstr})."
        rollback_exit
    fi

    node_mixed_count=0

    for node_id in ${node_ids[@]}
    do
        node_role_key="omada.cluster.distributed.${node_id}.role"
        node_role=${cluster_config["${node_role_key}"]}
        [ -z "${node_role}" ] && {
            echo "Node: ${node_id}, role is null."
            rollback_exit
        }
        if [[ "${node_id}" == "${NODE_ID}" ]]; then
            NODE_ROLE="${node_role}"
        fi
        if [[ ${node_role} == "mixed" ]]; then
            node_mixed_count=`expr $node_mixed_count + 1`
        elif [[ ${node_role} != "service" ]]; then
            echo "Node: ${node_id}, unknown role: ${node_role}."
            rollback_exit
        fi
        # get all node IP addresses
        node_ip_key="omada.cluster.distributed.${node_id}.host"
        node_ip_array+=(${cluster_config["${node_ip_key}"]})
        node_device_ip_key="omada.cluster.distributed.${node_id}.device.host"
        node_device_ip_array+=(${cluster_config["${node_device_ip_key}"]})
    done
    echo "Number of mixed members: $node_mixed_count"
    # 3~7 mixed nodes
    if [ $node_mixed_count -lt 3 ] || [ $node_mixed_count -gt 7 ] ; then
        echo "Current number of mixed members is $node_mixed_count. Please configure 3 to 7 mixed members."
        rollback_exit
    fi
    # name cannot be duplicated
    if [ $(echo "${node_ids[@]}" | tr ' ' '\n' | sort | uniq -d | wc -l) -ne 0 ]; then
        echo "node name cannot be duplicated."
        rollback_exit
    fi

    echo "Check node ips: ${node_ip_array[@]}"
    # ip cannot be duplicated
    if [ $(echo "${node_ip_array[@]}" | tr ' ' '\n' | sort | uniq -d | wc -l) -ne 0 ]; then
        echo "node ip cannot be duplicated."
        rollback_exit
    fi

     echo "Check node device hosts: ${node_device_ip_array[@]}"
     # device ip cannot be duplicated
     if [ $(echo "${node_device_ip_array[@]}" | tr ' ' '\n' | sort | uniq -d | wc -l) -ne 0 ]; then
         echo "node device host cannot be duplicated."
         rollback_exit
     fi

    replset_name=${cluster_config["omada.cluster.distributed.mongo.replset.name"]};
    [ -z "${replset_name}" ] && {
        echo "Replset name is null. Exit."
        rollback_exit
    }
    # cluster account
    horizontal_cluster_account_input_check

    primary_node=${cluster_config["omada.cluster.distributed.primary.data.node"]}
    [ -z "${primary_node}" ] && {
        primary_node="node1"
    }
    primary_node_role_key="omada.cluster.distributed.${primary_node}.role"
    primary_node_role=${cluster_config["${primary_node_role_key}"]}
    if [[ "${primary_node_role}" != "mixed" ]]; then
        echo "Primary data node role must be mixed."
        rollback_exit
    fi

    res="$(lsof -i:27217)"
    if [ ! -z "${res}" ]; then
        echo "MongoDB Port 27217 is occupied. Exit."
        echo "Please use 'sudo lsof -i:27217' to query the mongod process and execute 'sudo kill -15 <pid>' ."
        rollback_exit
    fi

    # ping all node
    ping_cluster_node
    NODE_HOST=${cluster_config["omada.cluster.distributed.${NODE_ID}.host"]}
}

horizontal_cluster_account_input_check() {
    read_input_name_key
    [ -z "${mongo_username}" ] && {
        echo "Cluster username is null. Exit."
        rollback_exit
    }

    [ -z "${cluster_key}" ] && {
        echo "Cluster key is null. Exit."
        rollback_exit
    }

}

read_input_name_key() {
    echo "Please set the cluster account, which will be used for authentication between cluster nodes. Please keep it consistent on all nodes."
    while true
    do
        read_input_name
        read_input_pwd
        read_input_sure
        if  [ 1 == $? ]; then
            break
        fi
    done

}

read_input_sure() {
    # enter again
    while true
    do
        read -r -s -p "Please confirm your cluster username (${mongo_username}), and enter your cluster password again: " cluster_key_confirm
        echo -ne "\n"
        if [[ $cluster_key_confirm == $cluster_key ]]; then
            return 1
        else
            echo "Inconsistent passwords."
            return 0
        fi

    done

}

read_input_name() {
    while true
    do
        read -r -p "Please enter your cluster username: " mongo_username

        if [[ "${mongo_username}" =~ ^[0-9A-Za-z]{1,64}$ ]]; then
            break
        else
            echo "Enter a value ranges from 1 to 64 characters. Characters should be uppercase letters, lowercase letters or numbers."
        fi
    done

}

read_input_pwd() {
    while true
    do
        read -r -s -p "Please enter your cluster password: " cluster_key

        strlen=`echo $cluster_key | grep -E '^(.{8,64}).*$'`
        strlow=`echo $cluster_key | grep -E '^(.*[a-z]+).*$'`
        strupp=`echo $cluster_key | grep -E '^(.*[A-Z]).*$'`
        strnum=`echo $cluster_key | grep -E '^(.*[0-9]).*$'`
        strts=`echo $cluster_key | grep -E '^(.*\W).*$'`

        if [ -n "${strlen}" ] && [ -n "${strlow}" ] && [ -n "${strupp}" ]  && [ -n "${strnum}" ] && [ -z "${strts}" ] ; then
            echo -ne "\n"
            break
        else
            echo -e "\nEnter a value ranges from 8 to 64 characters. Passwords must be a combination of uppercase letters, lowercase letters and numbers."
        fi

    done
}

wait_mongodb_startup() {
    count=10
    while [ $count -gt 0 ]; do
        sleep 2s
        res="$(lsof -i:27217)"
        if [ ! -z "${res}" ]; then
            break
        fi
        count=`expr $count - 1`
    done
    if [ $count -gt 0 ]; then
        return 0
    else
        echo "Failed to start mongodb, exit. Please check the properties file and node host."
        rollback_exit
    fi
}

wait_all_nodes_init() {
    mongo_members="{\"_id\":0,\"host\":\"${NODE_HOST}:27217\"}"
    cur_id=0
    for node_id in ${node_ids[@]}
    do
        node_host_key="omada.cluster.distributed.${node_id}.host"
        node_role_key="omada.cluster.distributed.${node_id}.role"
        node_host=${cluster_config["${node_host_key}"]}
        node_role=${cluster_config["${node_role_key}"]}
        if [[ "${node_host}" != "${NODE_HOST}" && "${node_role}" == "mixed" ]]; then
            cur_id=`expr $cur_id + 1`
            mongo_members="${mongo_members}, {\"_id\":${cur_id},\"host\":\"${node_host}:27217\"}"
        fi

    done
    echo "Mongo members: ${mongo_members}"
    count=1800
    while [[ ! "${res}" =~ "\"ok\" : 1" ]] && [[ ! "${res}" =~ "ok: 1" ]]; do
        sleep 5s
        # In higher versions of the shell, the output may be sent to standard error (STDerr) instead of standard output (UDT). 2>&1 capture needs to be added here
        res=$(${MONGODB_ORG_SHELL} ${MONGO_CLIENT_OPTS} "rs.initiate({\"_id\":\"${replset_name}\",\"members\":[${mongo_members}]});" 2>&1)
        echo ${res}
        count=`expr $count - 1`
        if [ $count -le 0 ]; then
            echo "Unable to connect to all nodes, please check network connection."
            return 1
        fi
    done
    echo "All nodes have been connected."
}

wait_mongo_member_init() {
    count=1800
    # In higher versions of the shell, the output may be sent to standard error (STDerr) instead of standard output (UDT). 2>&1 capture needs to be added here
    res=$(${MONGODB_ORG_SHELL} ${MONGO_CLIENT_OPTS} "rs.status();" 2>&1)
    echo "Wait for the primary node to respond. If the primary node does not respond for a long time, please check the network connection, configuration file or cluster account."
    while [[ "${res}" =~ "NotYetInitialized" ]] || [[ "${res}" =~ "no replset config has been received" ]]; do
        sleep 5s
        res=$(${MONGODB_ORG_SHELL} ${MONGO_CLIENT_OPTS} "rs.status();" 2>&1)
        echo "Wait for the primary node to respond. If the primary node does not respond for a long time, please check the network connection, configuration file or cluster account."
        count=`expr $count - 1`
        if [ $count -le 0 ]; then
            echo "Unable to connect to primary node, please check network connection."
            return 1
        fi
    done
    cur_id=0
    for node_id in ${node_ids[@]}
    do
        cur_id=`expr $cur_id + 1`
        if [[ "${node_host}" == "${NODE_HOST}" ]]; then
            break
        fi
    done
    if [ $cur_id -gt 1 ]; then
        cur_id=`expr $cur_id - 1`
    fi
    echo "Initializing data..."
    sleep 1m
    echo "Current node is ready."
}

init_failover_cluster() {
    failover_cluster_properties_check
    echo "Start the ${DESC} in Hot-Standby Backup mode."
    tpeap cluster ${CLUSTER_PROPERTIES_PATH} ${NODE_ID}
    rollback_exit
}

init_primary_mongo() {
    # use omada user
    configure_omada_user

    su ${OMADA_USER} -c "mongod ${MONGOD_OPTS}" > /dev/null
    wait_mongodb_startup
    res=$(${MONGODB_ORG_SHELL} ${NODE_HOST}:27217/local --quiet --eval "db.system.replset.find().limit(1);" 2>&1)
    [ ! -z "${res}" ] && {
        echo "The mongodb cluster has been initialized. Please do not repeat the initialization and use 'sudo tpeap start' to start it."
        su ${OMADA_USER} -c "mongod --shutdown --dbpath ${DB_DIR}" > /dev/null 2>&1
        rollback_exit
    }

    # create mongo user
    ${MONGODB_ORG_SHELL} ${NODE_HOST}:27217/admin --quiet --eval "db.createUser({user:\"${mongo_username}\", pwd:\"${cluster_key}\", roles:[{role: \"root\", db:\"admin\" }]})"
    su ${OMADA_USER} -c "mongod --shutdown --dbpath ${DB_DIR}" > /dev/null

    # create keyfile
    su ${OMADA_USER} -c "echo -n "${mongo_username}//${cluster_key}" | shasum -a 256 | cut -d ' ' -f1 | tee ${MONGO_KEY_FILE}" > /dev/null 2>&1
    chmod 600 ${MONGO_KEY_FILE}

    su ${OMADA_USER} -c "mongod ${MONGOD_REP_OPTS}" > /dev/null
    wait_mongodb_startup
    MONGO_CLIENT_OPTS="${NODE_HOST}:27217/admin -u ${mongo_username} -p ${cluster_key} --quiet --eval"
    wait_all_nodes_init
    if [ $? == 1 ]; then
        su ${OMADA_USER} -c "mongod --shutdown --dbpath ${DB_DIR}" > /dev/null 2>&1
        rollback_exit
    fi

}

init_member_mongo() {
    # use omada user
    configure_omada_user

    # clean up existed data
    echo "Init cluster member...Clean up mongodb data."
    rm -r -f ${DB_DIR}/*
    rm -f ${CLUSTER_DIR}/hsConfig

    su ${OMADA_USER} -c "mongod ${MONGOD_OPTS}" > /dev/null 2>&1
    wait_mongodb_startup

    # create mongo user
    ${MONGODB_ORG_SHELL} ${NODE_HOST}:27217/admin --quiet --eval "db.createUser({user:\"${mongo_username}\", pwd:\"${cluster_key}\", roles:[{role: \"root\", db:\"admin\" }]})"
    su ${OMADA_USER} -c "mongod --shutdown --dbpath ${DB_DIR}" > /dev/null

    # create keyfile
    su ${OMADA_USER} -c "echo -n "${mongo_username}//${cluster_key}" | shasum -a 256 | cut -d ' ' -f1 | tee ${MONGO_KEY_FILE}" > /dev/null 2>&1
    chmod 600 ${MONGO_KEY_FILE}

    # startup member mongodb
    su ${OMADA_USER} -c "mongod ${MONGOD_REP_OPTS}" > /dev/null
    MONGO_CLIENT_OPTS="${NODE_HOST}:27217/admin -u ${mongo_username} -p ${cluster_key} --quiet --eval"
    wait_mongo_member_init
    if [ $? == 1 ]; then
        su ${OMADA_USER} -c "mongod --shutdown --dbpath ${DB_DIR}" > /dev/null
        rollback_exit
    fi
}

init_internal_mongo_horizontal_cluster() {
    MONGOD_OPTS="--port 27217 --dbpath ${DB_DIR} --logappend --logpath ${MONGOD_LOG_PATH} \
         --bind_ip ${NODE_HOST} --fork"
    MONGO_KEY_FILE="${CLUSTER_DIR}/clusterKeyFile"
    MONGOD_REP_OPTS="${MONGOD_OPTS} -pidfilepath ${DATA_DIR}/mongo.pid --replSet ${replset_name} --auth --keyFile ${MONGO_KEY_FILE}"
    if [ "${NODE_ROLE}" == "mixed" ]; then
        echo "Current node role is mixed, start mongodb."
        if [[ ${primary_node} == ${NODE_ID} ]]; then
            init_primary_mongo
        else
            init_member_mongo
        fi
    fi
    echo "Start the ${DESC} in Distributed Cluster with internal mongodb."
    [ -e "${STARTUP_INFO_PATH}" ] && {
        rm ${STARTUP_INFO_PATH}
    }
    tpeap cluster ${CLUSTER_PROPERTIES_PATH} ${NODE_ID} ${mongo_username} ${cluster_key}
    rollback_exit
}

init_horizontal_cluster() {
    if [[ ${cluster_config["omada.cluster.distributed.mongo.mode"]} == "internal" ]]; then
        horizontal_cluster_properties_check
        init_internal_mongo_horizontal_cluster
    elif [[ ${cluster_config["omada.cluster.distributed.mongo.mode"]} == "external" ]]; then
        horizontal_cluster_external_properties_check
        echo "Start the ${DESC} in Distributed Cluster with external mongodb."
        tpeap cluster ${CLUSTER_PROPERTIES_PATH} ${NODE_ID}
    else
        echo "The vaule of key 'omada.cluster.distributed.mongo.mode' should be internal or external."
        rollback_exit
    fi

}

init_cluster() {
    is_running
    if  [ 1 == $? ]; then
        echo "${DESC} is already running."
        tpeap stop
    fi
    read_cluster_properties
    cluster_mode=${cluster_config["omada.cluster.mode"]}
    if [[ ${cluster_mode} == "distributed" ]]; then
        init_horizontal_cluster
    elif [ ${cluster_mode} == "hsb" ]; then
        init_failover_cluster
    else
        echo "The value '${cluster_mode}' of key 'omada.cluster.mode' is invalid."
        rollback_exit
    fi
}

# root permission check
check_root_perms
if [ $# != 5 ]; then
    help
    exit
elif [[ $1 != "-config" && $3 != "-node" && $5 != "init" ]]; then
    help
    exit
fi
[ ! -r $2 ] && {
    echo "$2 does not exist or is not readable."
    exit
}
CLUSTER_PROPERTIES_PATH=$(readlink -f $2)
chmod 666 ${CLUSTER_PROPERTIES_PATH}

# env check
check_env
# init cluster
init_cluster
