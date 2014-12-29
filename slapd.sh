#!/bin/sh

set -eu

status () {
  echo "---> ${@}" >&2
}

set -x
: LDAP_ROOTPASS=${LDAP_ROOTPASS}
: LDAP_DOMAIN=${LDAP_DOMAIN}
: LDAP_ORGANISATION=${LDAP_ORGANISATION}

if [ ! -e /var/lib/ldap/docker_bootstrapped ]; then
  status "configuring slapd for first run"

  cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${LDAP_ROOTPASS}
slapd slapd/internal/adminpw password ${LDAP_ROOTPASS}
slapd slapd/password2 password ${LDAP_ROOTPASS}
slapd slapd/password1 password ${LDAP_ROOTPASS}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANISATION}
slapd slapd/backend string HDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

  dpkg-reconfigure -f noninteractive slapd

  #sed -i "s/root/$EJABBERD_USER/g" ldap-db.ldif
  #sed -i "s/root/$EJABBERD_USER/g" lider_ahenk.ldif
  #sed -i "s/root/$EJABBERD_USER/g" load_ppolicy_modules.ldif
  sed -i "s/BASE_DN/$LDAP_BASE_DN/g" test-data.ldif
  sed -i "s/CONFIG_PASS/${LDAP_ROOTPASS}/g" config_password.ldif
  /usr/sbin/slapd -h "ldap:/// ldapi:///" -u openldap -g openldap
  sleep 5
  ldapmodify -Y EXTERNAL -H ldapi:/// -f config_password.ldif
  ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/ppolicy.ldif
  ldapmodify -Y EXTERNAL -H ldapi:/// -f load_ppolicy_modules.ldif
  ldapmodify -Y EXTERNAL -H ldapi:/// -f lider_ahenk.ldif
  ldapadd -D cn=admin,$LDAP_BASE_DN -w ${LDAP_ROOTPASS}  -H ldapi:/// -f test-data.ldif
  kill -INT `ps -eaf | awk '$8~"/usr/sbin/slapd" {print $2}'`
  touch /var/lib/ldap/docker_bootstrapped
else
  status "found already-configured slapd"
fi

status "starting slapd"
set -x
exec /usr/sbin/slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -d0
