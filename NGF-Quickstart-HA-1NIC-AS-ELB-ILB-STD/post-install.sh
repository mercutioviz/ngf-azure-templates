#!/bin/bash
curl -s https://raw.githubusercontent.com/mercutioviz/ngf-azure-templates/master/NGF-Quickstart-HA-1NIC-AS-ELB-ILB-STD/simple-ha.fwrule > /tmp/template.fwrule
red=$1
green=$2
echo "Red subnet: $1" >> /tmp/post-install.log
echo "Green subnet: $2" >> /tmp/post-install.log
cp /tmp/template.fwrule /tmp/active.fwrule
perl -pi -e "s#placeholder_azure_subnet_red#${red}RMASK#g" /tmp/active.fwrule
perl -pi -e "s#placeholder_azure_subnet_green#${green}RMASK#g" /tmp/active.fwrule
perl -pi -e 's#(\d+)RMASK#(32 - $1)#e' /tmp/active.fwrule
acpfrule check /tmp/active.fwrule && cp /tmp/active.fwrule /opt/phion/config/configroot/servers/S1/services/NGFW/ && cp /tmp/active.fwrule /opt/phion/config/active/servers/S1/services/NGFW/ && /opt/phion/modules/server/firewall/bin/activate
sleep 1
