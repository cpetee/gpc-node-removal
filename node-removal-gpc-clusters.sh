##cpetee april 2026
## help from AI
#!/bin/bash

# Function to prompt for input with a default value
prompt_var() {
    local var_name=$1
    local prompt_text=$2
    local default_value=$3
    read -p "$prompt_text [$default_value]: " input
    echo "${input:-$default_value}"
}

echo "------------------------------------------"
echo "   GPC Node Removal Worklog Generator     "
echo "------------------------------------------"

# Interactive Prompts
CLUSTER_PREFIX=$(prompt_var "CLUSTER_PREFIX" "Enter Cluster Prefix" "example-cluster")
SERVER_LIST=$(prompt_var "SERVER_LIST" "Enter Server List (e.g. node3, node4)" "node3, node4")
CASE_ID=$(prompt_var "CASE_ID" "Enter Case ID" "0000000")
CLIENT_ID=$(prompt_var "CLIENT_ID" "Enter Client ID" "12345")
REDIS_INSTANCE1=$(prompt_var "REDIS_INSTANCE1" "Enter Redis Instance 1" "inst1")
REDIS_INSTANCE2=$(prompt_var "REDIS_INSTANCE2" "Enter Redis Instance 2" "inst2")
INTERNAL_IP_FS1=$(prompt_var "INTERNAL_IP_FS1" "Enter FS1 Internal IP" "10.0.0.1")
INTERNAL_IP_NODES_REMOVED=$(prompt_var "INTERNAL_IP_NODES_REMOVED" "Enter Removed Nodes IP Range" "10.0.0.[x-y]")

# Domain Array Logic
read -p "Enter Domains (separated by spaces) [example.com]: " DOMAIN_INPUT
DOMAIN_INPUT=${DOMAIN_INPUT:-"example.com"}
# Convert input string into a proper array
read -a DOMAIN_ARRAY <<< "$DOMAIN_INPUT"
# Format array into a newline-separated string
DOMAIN_LIST=$(printf "%s\n" "${DOMAIN_ARRAY[@]}")

echo -e "\n--- Generating Document ---\n"

# The Template
TEMPLATE=$(cat << 'EOF'
Waypoint reference: https://waypoint.liquidweb.com:8443/display/SUP/GPC+Node+Removals
target cluster: <CLUSTER PREFIX>
target server to be removed: <SERVER LIST>
Support case: <CASE ID>
Client account: https://nocworx.nexcess.net/client/<CLIENT ID>
 
Steps to following
update client in case:  <CASE ID>

also update OCC team in #nw-watchers
Please ignore alerts for  <CLUSTER PREFIX>-* and scheduled maintenance is being worked on.
update Inventory blacklist

add following to inventories/blacklist.txt in ansible
<CLUSTER PREFIX>-node#.us-midwest-1.nxcli.net
<CLUSTER PREFIX>-node#.us-midwest-1.nxcli.net
Pause status cake

https://app.statuscake.com/Login/?redirect=/YourStatus2.php
Pause Statuscake monitoring for the server(s) being removed
Use the "NX-SOS Fleet StatusCake [rmacdonaldnexcessnet]" entry in Bitwarden
Search for the hostnames
Hit the pause button on the test (if a resume button is seen instead, that means that the test is already paused)
Regenerate the Ansible inventory (perform on esg-ansible)

sudo /usr/local/sbin/getinv
Take a backup of the HAProxy and Varnish configuration (perform on <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net )
rsync -aAXvP /etc/haproxy/ "/etc/haproxy-<CASE ID>-$(date --iso-8601=minute)"

rsync -aAXvP /etc/varnish/ "/etc/varnish-<CASE ID>-$(date --iso-8601=minute)"

Enable maintenance mode on the sites via HAProxy (performed on <CLUSTER PREFIX>-lb1)
Edit /etc/haproxy/lists/maintenance-domains.txt and add:

<DOMAINS>

Reload HAProxy

haproxy -c -V -f /etc/haproxy/conf/ -f /etc/haproxy/conf.d/ && systemctl reload haproxy

Disable local document roots (performed on esg-ansible server)
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/local-docroot.yml -t disable

Run any applicable playbooks from ansible server

HAProxy:
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/haproxy.yml

Varnish:
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/varnish.yml

Local docroots:
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/local-docroot.yml

Redis: (skip is no replicas is being used)
stop each instances on the web nodes (example for 2 instances,update to reflect for both)
systemctl stop redis-multi-<REDIS_INSTANCE1>-replica.service

systemctl stop redis-multi-<REDIS_INSTANCE2>-replica.service

systemctl status redis-multi-<REDIS_INSTANCE1>-replica.service

systemctl status redis-multi-<REDIS_INSTANCE2>-replica.service

and then Reset from the Master instance (<CLUSTER PREFIX>-fs1)
(connect to SENTINEL)
redis-cli -h <INTERNAL_IP_FS1> -p 5000

rest each instance:
SENTINEL RESET <REDIS_INSTANCE1>-cache 

SENTINEL RESET <REDIS_INSTANCE2>-cache

Enable local docroots on <CLUSTER PREFIX> cluster(performed on esg-ansible server)
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/local-docroot.yml -t enable

!! THIS IS THE MOST IMPORTANT STEP !! Drop the nodes from Interworx (performed within Nodeworx panel on cluster's lb)

Get Nodeworx URL:
me <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net

nw
Open Link and navigate:
Access "Clustering" -> "Nodes"
Select associated nodes being removed (select node# and node#)
"With Selected: Delete"

10) Allow access from your IP addresss and perform simple testing on the site
me <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net 

vim /etc/haproxy/maps/whitelist-ips.map

haproxy -c -V -f /etc/haproxy/conf/ -f /etc/haproxy/conf.d/ && systemctl reload haproxy

This is to ensure that nothing appears obviously broken

Load sites in browser and navigate.
<DOMAINS>
11)  Verify that no traffic is routing to the old nodes
Should not have any data, only this should be getting traffic:
tail -f /var/log/interworx/<INTERNAL_IP_NODES_REMOVED>/*/logs/transfer.log
EG: tail -f /var/log/interworx/172.18.124.16[3-4]/*/logs/transfer.log

12) Assist the client in testing the site and update ticket (may not be needed if client is not available and we confirmed sites are loading from other nodes)
may need to whitelist their IP(s), see step 10)
me <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net 

vim /etc/haproxy/maps/whitelist-ips.map

13) Remove maintenance:
me <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net
vim /etc/haproxy/lists/maintenance-domains.txt and remove/comment out:

<DOMAINS>
haproxy -c -V -f /etc/haproxy/conf/ -f /etc/haproxy/conf.d/ && systemctl reload haproxy

14) update OCC team in #nw-watchers
Please resume alerts for <CLUSTER PREFIX>-* and scheduled maintenance is now completed. node# and node# have been removed from the cluster
15) Reach out to Sales to adjust invoicing and for them to work with DCops on decommissioning the <CLUSTER PREFIX>-node# and <CLUSTER PREFIX>-node# servers.
EOF
)

# Perform Replacements
# Note: Using perl for the domain replacement to handle the newlines in $DOMAIN_LIST cleanly
echo "$TEMPLATE" | sed \
    -e "s/<CLUSTER PREFIX>/$CLUSTER_PREFIX/g" \
    -e "s/<SERVER LIST>/$SERVER_LIST/g" \
    -e "s/<CASE ID>/$CASE_ID/g" \
    -e "s/<CLIENT ID>/$CLIENT_ID/g" \
    -e "s/<REDIS_INSTANCE1>/$REDIS_INSTANCE1/g" \
    -e "s/<REDIS_INSTANCE2>/$REDIS_INSTANCE2/g" \
    -e "s/<INTERNAL_IP_FS1>/$INTERNAL_IP_FS1/g" \
    -e "s/<INTERNAL_IP_NODES_REMOVED>/$INTERNAL_IP_NODES_REMOVED/g" | \
    perl -pe "s/<DOMAINS>/$DOMAIN_LIST/g"
