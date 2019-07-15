#!/bin/sh
set -e
kinit -k -t /var/rt2/krbsnap.keytab krbsnap@ATHENA.MIT.EDU
aklog athena.mit.edu
f=rt.dump.`date +%Y.%m.%d`
a=/afs/athena.mit.edu/astaff/project/krbdev/krbdev.mit.edu/backups/dumps
d=/var/rt2/dumps
pg_dump -U postgres -c -f $d/$f rt4
gzip -9 $d/$f
cp -p --no-preserve=ownership $d/$f.gz $a
find $a -name 'rt.dump.*.gz' -mtime +3 -exec rm {} \;
find $d -name 'rt.dump.*.gz' -mtime +30 -exec rm {} \;
#gzip -c -9 /var/repository-tar/krb5.tar >/var/repository-tar/krb5.tar.gz.tmp \
#  &&mv /var/repository-tar/krb5.tar.gz.tmp /var/repository-tar/krb5.tar.gz
#/var/postgres/bin/vacuumdb -U postgres -d rt2 -z -q
find /opt/rt4/var/session_data -type f -mtime +1 -print0 | xargs -0 rm
find /opt/rt4/var/mason_data -type f -mtime +1 -print0 | xargs -0 rm
kdestroy
unlog
