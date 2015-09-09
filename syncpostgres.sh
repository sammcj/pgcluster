#!/bin/bash
#
# Syncs postgresql DATA from one node to another.
# Expects STANDBY_NODE_IP, ACTIVE_NODE_IP and PG_VERSION

echo "Note: you must have ssh agent forwarding enabled (ssh-add, ssh -A root@server)"

ssh root@${STANDBY_NODE_IP} "echo 'SSH forwarding working...'"
if [[ $? != 0 ]]; then
    echo "SSH forwarding is not enabled, you must ssh -A into this server before running this script!"
    echo "try: ssh -A root@${HOSTNAME}"
    exit 1
fi

echo "This script will wipe the STANDBY node, then copy all data from the ACTIVE node to the STANDBY node and bring it online."
echo ""
echo "The current active node has been detected as $(getent hosts ${ACTIVE_NODE_IP})"
echo "The current standby node has been detected as $(getent hosts ${STANDBY_NODE_IP})"
echo ""
read -r -p "Are you sure you want to continue? [y/N] " response

case $response in
  [yY][eE][sS]|[yY])
    echo "Stopping puppet on the STANDBY..."
    ssh root@${STANDBY_NODE_IP} puppet agent --disable
    echo "Stopping postgres on the STANDBY..."
    ssh root@${STANDBY_NODE_IP} /etc/init.d/postgresql stop
    echo "Cleaning up old cluster directory on the STANDBY..."
    ssh root@${STANDBY_NODE_IP} sudo -u postgres rm -rf /var/lib/postgresql/${PG_VERSION}/main
    echo "Starting base backup..."
    ssh root@${STANDBY_NODE_IP} cd /tmp && sudo -u postgres pg_basebackup -h ${ACTIVE_NODE_IP} -D /var/lib/postgresql/${PG_VERSION}/main -X stream -U postgres -v -P --write-recovery-conf
    echo "DONE, starting PostgreSQL on ${STANDBY_NODE_IP} ..."
    ssh root@${STANDBY_NODE_IP} /etc/init.d/postgresql start
    echo "DONE, re-enabling puppet on ${STANDBY_NODE_IP} ..."
    ssh root@${STANDBY_NODE_IP} puppet agent --enable
    ;;
  *)
    exit
    ;;
esac
