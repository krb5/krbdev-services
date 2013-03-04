# Shell script to convert MIT krb5-appl repository from svn to git.
# Run in an empty directory with about 100MB of free space.

# Requires AFS to get at the krb5-appl repository mirror.  Requires
# Python 2.7 for edit-logs.py.  Requires svnlook, svnadmin, and git in
# the path.  Requires gnu cp for the -a option.

set -e

datadir=`dirname $0`
if [ ! -r "$datadir/authors" ]; then
    echo "Can't find authors file; run using absolute path" 1>&2
    exit 1
fi

wd=`pwd`
mirror=/afs/athena.mit.edu/astaff/project/krbdev/svn/krb5-appl
svncopy=$wd/appl-svn
gitsvn=$wd/appl-gitsvn
bare=$wd/krb5-appl.git

echo "Copying krb5-appl repository mirror to $svncopy"
cp -a "$mirror" "$svncopy"

echo "Editing log messages in $svncopy"
python "$datadir/edit-logs.py" "$svncopy"

echo "Initializing $gitsvn"
git svn init --stdlayout --rewrite-root=svn://anonsvn.mit.edu/krb5-appl \
    "file://$svncopy" "$gitsvn" > /dev/null

echo "Fetching svn revisions into $gitsvn (output in git-svn-fetch.log)"
(cd "$gitsvn" && git svn fetch "--authors-file=$datadir/authors") \
    > git-svn-fetch.log 2>&1

echo "Creating $bare"
git init -q --bare "$bare"

echo "Pushing from $gitsvn to $bare"
(cd "$gitsvn" && git push -q "$bare" 'refs/remotes/*:refs/heads/*')

# Everything from here on is manipulation of the bare repository.
cd "$bare"

echo "Adjusting branches and tags"

# Rename branches (and tags, which are currently branches named tags/*).
while read src dest; do
    git branch -m "$src" "$dest"
done < "$datadir/branch-renames.appl"

# Convert tags/* branches to tags.
git for-each-ref --format='%(refname)' refs/heads/tags | cut -d / -f 4 | \
    while read ref; do
        git tag "$ref" "refs/heads/tags/$ref";
        git branch -D "tags/$ref";
    done > /dev/null

echo "Packing repository"
git gc --quiet --aggressive --prune=now

echo "Configuring repository"
echo "Master krb5-appl git repository" > description
git remote add --mirror=push github-krb5-appl git@github.com:krb5/krb5-appl.git
git config core.sharedRepository group
git config core.logAllRefUpdates true
git config gc.reflogexpire never
git config gc.reflogexpireunreachable never

# Configure variables used by hook scripts.
git config hooks.verbose true
git config hooks.mailinglist krb5-appl-commits@mit.edu
git config hooks.reponame krb5-appl
git config hooks.rt-ssh-cmd "/git/krb5-appl.git/hooks/ssh-as-krbsnap rtcvs@krbdev-r1.mit.edu /var/rt2/bin/rt-cvsgate"
git config hooks.commit-url-prefix "https://github.com/krb5/krb5-appl/commit/"
git config hooks.push-to github-krb5-appl

# Configure variables controlling git-receive-pack behavior.
git config receive.fsckObjects true
git config receive.denyNonFastForwards true

# Install hook scripts (except krb5-rt-id).
rm hooks/*
cp $datadir/../githooks/* hooks
rm hooks/krb5-rt-id
