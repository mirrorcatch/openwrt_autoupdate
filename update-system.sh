#!/bin/ash

opkg list-installed > /mnt/sda3/backup-userinstalledpackages-${HOSTNAME}-$(date +%F).txt

umask go=
sysupgrade -b /tmp/backup-${HOSTNAME}-$(date +%F).tar.gz
mv /tmp/backup-* /mnt/sda3
ls /mnt/sda3/backup-*.tar.gz

# delete backups older than 30 days
rm -f $(find /mnt/sda3/backup-* -mtime +31)

opkg update
# upgrade netifd first as it causes drop out and system upgrade fails
opkg upgrade netifd
# install luci-ssl, so we get web back after upgrades
opkg install luci-ssl
/etc/init.d/uhttpd restart
# do package upgrades
PACKAGES="$(opkg list-upgradable |awk '{print $1}')"
if [ -n "${PACKAGES}" ]; then
  opkg upgrade ${PACKAGES}
  if [ "$?" -eq 0 ]; then
    echo "$(date -I"seconds") - update success, waiting to reboot" \
>> /www/update.result

    # workaround for carrier requiring 15 minute PPPoE timeout
    uci set network.Internet.disabled="1"
    service network reload
    sleep 20m
    uci set network.Internet.disabled="0"

    echo "$(date -I"seconds") - rebooting now"
    exec reboot
  else
    echo "$(date -I"seconds") - update failed" >> /www/update.result
  fi
else
  echo "$(date -I"seconds") - nothing to update" >> /www/update.result
fi
