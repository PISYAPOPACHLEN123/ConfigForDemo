#!/bin/bash
# Exit on any error to prevent partial execution
set -e
# Set system hostname
hostnamectl set-hostname ISP
# Delete all existing connections
nmcli connection show | grep -v "NAME" | awk '{print $1}' | while read -r conn; do
    nmcli connection delete "$conn"
done
# Add new connection for ens18
nmcli connection add type ethernet con-name ens18 ifname ens18 ipv4.method auto ipv6.method disabled
# Add new connection for ens19
nmcli connection add type ethernet con-name ens19 ifname ens19 ipv4.method manual ipv4.addresses 172.16.4.1/28 ipv6.method disabled
# Add new connection for ens20
nmcli connection add type ethernet con-name ens20 ifname ens20 ipv4.method manual ipv4.addresses 172.16.5.1/28 ipv6.method disabled
# Restart all network adapters
nmcli networking off
nmcli networking on
# Reboot the system
reboot
# Enable and start firewalld
systemctl enable --now firewalld
# Assign interfaces to firewall zones
firewall-cmd --zone=external --change-interface=ens18 --permanent
firewall-cmd --zone=internal --change-interface=ens19 --permanent
firewall-cmd --zone=internal --change-interface=ens20 --permanent
firewall-cmd --zone=internal --add-forward --permanent
firewall-cmd --reload
# Reboot the system
reboot
# Verify active firewall zones
firewall-cmd --get-active-zones
# Modify IP forwarding settings
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
sed -i 's/net.ipv4.conf.default.rp_filter = 1/net.ipv4.conf.default.rp_filter = 0/' /etc/sysctl.conf
# Apply sysctl changes
sysctl -p
# Set timezone to Europe/Moscow
timedatectl set-timezone Europe/Moscow
# Final reboot
reboot