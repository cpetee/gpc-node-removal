#!/bin/bash
##cpetee april 2026
## help from AI (gemini) from initial script/template)

#!/bin/bash

# Function to prompt for input with a default value
prompt_var() {
    local prompt_text=$2
    local default_value=$3
    read -p "$prompt_text [$default_value]: " input
    echo "${input:-$default_value}"
}

echo "------------------------------------------"
echo "   GPC Node Removal Worklog Generator     "
echo "------------------------------------------"

# 1. Basic Info
CLUSTER_PREFIX=$(prompt_var "" "Enter Cluster Prefix" "example-cluster")
CASE_ID=$(prompt_var "" "Enter Case ID" "0000000")
CLIENT_ID=$(prompt_var "" "Enter Client ID" "12345")
CLIENT_TEAM=$(prompt_var "" "Enter Client Team Name" "ClientName")
INTERNAL_IP_FS1=$(prompt_var "" "Enter FS1 Internal IP" "10.0.0.1")
INTERNAL_IP_NODES_REMOVED=$(prompt_var "" "Enter Removed Nodes IP Range" "10.0.0.[x-y]")

# 2. Server List Logic
read -p "Enter Nodes (separated by spaces, e.g., node5 node6): " NODE_INPUT
read -a NODE_ARRAY <<< "$NODE_INPUT"
# Create formatted versions
NODE_BULLET_LIST=$(printf -- "- ${CLUSTER_PREFIX}-%s.us-midwest-1.nxcli.net\n" "${NODE_ARRAY[@]}")
NODE_COMMA_LIST=$(printf ", %s" "${NODE_ARRAY[@]}" | cut -c 3-)
NODE_BLACKLIST=$(printf "${CLUSTER_PREFIX}-%s.us-midwest-1.nxcli.net\n" "${NODE_ARRAY[@]}")
NODE_INT_LIST=$(printf "${CLUSTER_PREFIX}-%s-int\n" "${NODE_ARRAY[@]}")

# 3. Redis Instance Logic (Dynamic Array)
read -p "Enter Redis Instances (separated by spaces, e.g., inst1 inst2, from 'nkredi info' on node, exclude "-cache-replica" pattern): " REDIS_INPUT
read -a REDIS_ARRAY <<< "$REDIS_INPUT"

REDIS_STOP_BLOCK=""
REDIS_STATUS_BLOCK=""
REDIS_RESET_BLOCK=""

for inst in "${REDIS_ARRAY[@]}"; do
    REDIS_STOP_BLOCK+=$'systemctl stop redis-multi-'"$inst"$'-cache-replica.service\n'
    REDIS_STATUS_BLOCK+=$'systemctl status redis-multi-'"$inst"$'-cache-replica.service\n'
    REDIS_RESET_BLOCK+=$'SENTINEL RESET '"$inst"$'\n'
done

# 4. Domain Logic
read -p "Enter Domains (separated by spaces): " DOMAIN_INPUT
read -a DOMAIN_ARRAY <<< "$DOMAIN_INPUT"
DOMAIN_LIST=$(printf "%s\n" "${DOMAIN_ARRAY[@]}")

echo -e "\n--- Generating Document ---\n"

# The Template
TEMPLATE=$(cat << 'EOF'
WEB <NODE_COMMA_LIST> REMOVAL
--------------------
Nodes to remove:
<NODE_BULLET_LIST>

Status  |  Step  |  Action                                                                            |  Who
-----------------------------------------------------------------------------------------------------------------------------------------------
[ ]     |  0)    |  Update client in case and update OCC in #nw-watchers                              |  ( Nexcess )
[ ]     |  1)    |  Merge Inventory blacklist                                                         |  ( Nexcess )
[ ]     |  2)    |  Pause Status Cake                                                                 |  ( Nexcess )
[ ]     |  3)    |  Regenerate the Ansible inventory (perform on esg-ansible)                         |  ( Nexcess )
[ ]     |  4)    |  Backup HAProxy and Varnish configuration                                          |  ( Nexcess )
[ ]     |  5)    |  Enable maintenance mode on the sites via HAProxy                                  |  ( Nexcess )
[ ]     |  6)    |  Disable local document roots (on esg-ansible)                                     |  ( Nexcess )
[ ]     |  7)    |  Run Ansible playbooks (on esg-ansible)                                            |  ( Nexcess )
[ ]     |  8)    |  Enable local docroots (on esg-ansible)                                            |  ( Nexcess )
[ ]     |  9)    |  !! THIS IS THE MOST IMPORTANT STEP !! Drop the nodes from Interworx (on <CLUSTER PREFIX>-lb1) |  ( Nexcess )
[ ]     |  10)   |  Allow access from your IP addresss and perform simple testing                     |  ( Nexcess )
[ ]     |  11)   |  Verify that no traffic is routing to the old nodes                                |  ( Nexcess )
[ ]     |  12)   |  Assist the client in testing the site                                             |  ( Nexcess/<CLIENT_TEAM>)
[ ]     |  13)   |  Remove maintenance                                                                |  ( Nexcess )
[ ]     |  14)   |  Update OCC team in #nw-watchers                                                   |  ( Nexcess )
[ ]     |  15)   |  Re-enable Status Cake alert                                                       |  ( Nexcess )
[ ]     |  16)   |  Pass back to ESG Projects for decommissioning <NODE_COMMA_LIST>                   |  ( Nexcess )

Notes by step:
--------------
0) Update client in case: <CASE ID>
- Also update OCC team in #nw-watchers
Please ignore alerts for  <CLUSTER PREFIX>-* and scheduled maintenance is being worked on.

1) Update and Merge Inventory blacklist
add following to inventories/blacklist.txt in ansible
<NODE_BLACKLIST>
- Verify the following is in inventories/blacklist.txt in ansible
<NODE_BLACKLIST>

2) Pause status cake
https://app.statuscake.com/Login/?redirect=/YourStatus2.php
- Pause Statuscake monitoring for the server(s) being removed
Use the "NX-SOS Fleet StatusCake [rmacdonaldnexcessnet]" entry in Bitwarden
Search for the hostnames
Hit the pause button on the test (if a resume button is seen instead, that means that the test is already paused)

3) Regenerate the Ansible inventory (perform on esg-ansible)
sudo /usr/local/sbin/getinv

4) Backup HAProxy and Varnish configuration (perform on <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net )
rsync -aAXvP /etc/haproxy/ "/etc/haproxy-<CASE ID>-$(date --iso-8601=minute)"
rsync -aAXvP /etc/varnish/ "/etc/varnish-<CASE ID>-$(date --iso-8601=minute)"

5) Enable maintenance mode on the sites via HAProxy (performed on <CLUSTER PREFIX>-lb1)
- Edit /etc/haproxy/lists/maintenance-domains.txt and add:
<DOMAINS>
- Reload HAProxy
haproxy -c -V -f /etc/haproxy/conf/ -f /etc/haproxy/conf.d/ && systemctl reload haproxy

6) Disable local document roots (performed on esg-ansible server)
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/local-docroot.yml -t disable

7) Run any applicable playbooks from ansible server
- HAProxy:
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/haproxy.yml
- Varnish:
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/varnish.yml
- Local docroots: Run in tmux or screen 
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/local-docroot.yml
- Redis: stop each instances on the web nodes being removed
<REDIS_STOP_BLOCK>
<REDIS_STATUS_BLOCK>
- Reset from the Master instance (<CLUSTER PREFIX>-fs1)
(connect to SENTINEL)
redis-cli -h <INTERNAL_IP_FS1> -p 5000

rest each instance:
<REDIS_RESET_BLOCK>

8) Enable local docroots on <CLUSTER PREFIX> cluster(performed on esg-ansible server)
- This can take a bit so run it in a screen or tmux.
ansible-playbook <CLUSTER PREFIX>_prod /playbooks/local-docroot.yml -t enable

9) !! THIS IS THE MOST IMPORTANT STEP !! Drop the nodes from Interworx (performed within Nodeworx panel on cluster's lb)
- Access Nodeworx URL:
me <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net
nw
- Go to "Clustering" -> "Nodes"
- Select associated nodes being removed:
<NODE_INT_LIST>
- "With Selected: Delete"

10) Allow access from your IP addresss and perform simple testing on the site
me <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net 
vim /etc/haproxy/maps/whitelist-ips.map
haproxy -c -V -f /etc/haproxy/conf/ -f /etc/haproxy/conf.d/ && systemctl reload haproxy
- This is to ensure that nothing appears obviously broken
- Load sites in browser and navigate. 
<DOMAINS>

11)  Verify that no traffic is routing to the old nodes
- Should not have any data, only this should be getting traffic:
tail -f /var/log/interworx/<INTERNAL_IP_NODES_REMOVED>/*/logs/transfer.log
EG: tail -f /var/log/interworx/172.18.124.16[3-4]/*/logs/transfer.log

12) Assist the client in testing the site and update ticket
- may need to whitelist their IP(s), see step 10)
me <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net 
vim /etc/haproxy/maps/whitelist-ips.map
haproxy -c -V -f /etc/haproxy/conf/ -f /etc/haproxy/conf.d/ && systemctl reload haproxy

13) Remove maintenance
me <CLUSTER PREFIX>-lb1.us-midwest-1.nxcli.net 
vim /etc/haproxy/lists/maintenance-domains.txt 
- remove/comment out:
<DOMAINS>
- Haproxy syntax check and reload 
haproxy -c -V -f /etc/haproxy/conf/ -f /etc/haproxy/conf.d/ && systemctl reload haproxy

14) Update OCC team in #nw-watchers
Please resume alerts for <CLUSTER PREFIX>-* and scheduled maintenance is now completed. <NODE_COMMA_LIST> have been removed from the cluster

15) Re-enable Status Cake alert 
https://app.statuscake.com/Login/?redirect=/YourStatus2.php
- Unpause Statuscake monitoring for the server(s) being removed
Search for the hostnames
Hit the pause button (Verify test is UP and not paused)

16) Pass back to ESG Projects for decommissioning <NODE_COMMA_LIST>
EOF
)

# Final Output with Multi-Line Replacements
echo "$TEMPLATE" | sed \
    -e "s/<CLUSTER PREFIX>/$CLUSTER_PREFIX/g" \
    -e "s/<CASE ID>/$CASE_ID/g" \
    -e "s/<CLIENT_TEAM>/$CLIENT_TEAM/g" \
    -e "s/<INTERNAL_IP_FS1>/$INTERNAL_IP_FS1/g" \
    -e "s/<INTERNAL_IP_NODES_REMOVED>/$INTERNAL_IP_NODES_REMOVED/g" | \
    perl -pe "s|<NODE_BULLET_LIST>|$NODE_BULLET_LIST|g; \
              s|<NODE_COMMA_LIST>|$NODE_COMMA_LIST|g; \
              s|<NODE_BLACKLIST>|$NODE_BLACKLIST|g; \
              s|<NODE_INT_LIST>|$NODE_INT_LIST|g; \
              s|<REDIS_STOP_BLOCK>|$REDIS_STOP_BLOCK|g; \
              s|<REDIS_STATUS_BLOCK>|$REDIS_STATUS_BLOCK|g; \
              s|<REDIS_RESET_BLOCK>|$REDIS_RESET_BLOCK|g; \
              s|<DOMAINS>|$DOMAIN_LIST|g"
