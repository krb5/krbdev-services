#!/bin/sh
set -e
kinit -k -t /var/rt2/krbsnap.keytab krbsnap@ATHENA.MIT.EDU
aklog athena.mit.edu
f=rt.dump.`date +%Y.%m.%d`
a=/afs/athena.mit.edu/astaff/project/krbdev/krbdev.mit.edu/backups/dumps
d=/var/rt2/dumps
trunksnap=/afs/athena.mit.edu/astaff/project/kerberos/krb5-current
buildmaster=/var/lib/buildbot/master
pg_dump -U postgres -c -f $d/$f rt2
gzip -9 $d/$f
cp -p --no-preserve=ownership $d/$f.gz $a
find $a -name 'rt.dump.*.gz' -mtime +3 -exec rm {} \;
find $d -name 'rt.dump.*.gz' -mtime +30 -exec rm {} \;
(cd $trunksnap && tar zxof $buildmaster/rst_html.tgz)
#gzip -c -9 /var/repository-tar/krb5.tar >/var/repository-tar/krb5.tar.gz.tmp \
#  &&mv /var/repository-tar/krb5.tar.gz.tmp /var/repository-tar/krb5.tar.gz
#/var/postgres/bin/vacuumdb -U postgres -d rt2 -z -q
find /var/rt2/WebRT/sessiondata -type f -mtime +1 -print|xargs rm
kdestroy
unlog
