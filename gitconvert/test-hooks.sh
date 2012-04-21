# Script to test krb5 hook scripts.  Run in an empty directory.
# git's default idea of your email address must match the mapping of
# your username in githooks/authors.

datadir=`dirname $0`
wd=`pwd`

# Create test master repository with hooks.
rm -rf central
git init --bare central
cd central
cp $datadir/../githooks/* hooks
cp $datadir/test-cvsgate hooks
git config hooks.mailinglist -
git config hooks.reponame testrepo
git config hooks.rt-ssh-cmd $wd/central/hooks/test-cvsgate
git remote add github-krb5 $wd/mirror
git config remote.github-krb5.mirror true
git config receive.denyNonFastForwards true
cd ..

# Create test push target.
rm -rf mirror
git init --bare mirror

# Create test client repository.
rm -rf client
git init client
cd client
git remote add central $wd/central

# Make some commits on master testing post-receive-notify and post-receive-rt.
# (After the first commit, create a branch to be fast-forwarded later.)
printf "testfile1\nline2\n" > file1
git add file1
git commit -m "One line commit message"
git branch test-ff
echo line3 >> file1
git commit -a -m "Multi-line commit message

with valid summary and no RT headers"
echo testfile2 > file2
git add file2
git commit -m "Commit message

with a body and then RT headers (but nothing special)
ticket: 1234
target_version: 1.3"
echo line2file2 >> file2
echo line4 >> file1
git commit -a -m "Another commit message with RT headers

ticket: 1235 (new)
tags: pullup
subject: Subject supplied in RT headers"
git rm file2
git commit -a -m "Summary line acting as ticket subject

because RT headers imply new ticket but do not contain subject

ticket: 1236 (new)
version_fixed: 1.3"
perl -e 'print "\n" x 5000 . "foo\n"' > bigfile
git add bigfile
git commit -m "Big diff suppressed"

# Create a branch at the same rev as master (to test that revs are
# only processed once in a push, even if they're new to several
# branches).
git branch test-duplicate

# Push what we have so far.
npush=0
push() {
    : $((npush = npush + 1))
    echo "****** Push $npush"
    git push central "$@"
    echo "****** End push $npush"
}

push master test-ff test-duplicate

# Fast-forward a branch along master and test that we get a notification
# about the branch head move but not about the existing commits.
git update-ref refs/heads/test-ff refs/heads/master
push test-ff

# Make a branch with more than 50 commits.  This will hopefully never
# happen in practice, but this tests the sanity check in post-receive
# which makes sure we don't spam the list if it erroneously identifies
# a large number of commits.
git checkout -b longbranch
for i in 0 1 2 3 4 5; do for j in 0 1 2 3 4 5 6 7 8 9; do
    echo $i$j > busyfile
    git add busyfile
    git commit -m "Commit $i$j to longbranch"
done; done
push longbranch
git checkout master

# Test notifications for tags.
git tag -a -m "Annotated tag message" atag
git tag ntag
push atag ntag

# Hooks should reject a commit deleting a branch or tag.
push :refs/tags/ntag :refs/heads/test-duplicate

# Hooks should reject a non-fast-forward update.
push -f master^:master

# Hooks should reject a ref which isn't a branch or tag.
push master:refs/non/branchtag

# Make a bunch of branches containing bad commits.

# Committer address doesn't match mapping in authors file.
git checkout -b reject1
echo line5 >> file1
git -c user.email=fake@fake.fake commit -a -m "Wrong committer address"
git checkout master

# "ticket: new" in message (instead of "ticket: NNNN (new)").
git checkout -b reject2
echo line5 >> file1
git commit -a -m "Valid summary line

ticket: new"
git checkout master

# Empty message.
git checkout -b reject3
echo line5 >> file1
git commit -a --allow-empty-message -m ''
git checkout master

# Summary line too long.
git checkout -b reject4
echo line5 >> file1
git commit -a -m abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ
git checkout master

# Summary line ends with period.
git checkout -b reject5
echo line5 >> file1
git commit -a -m "Hi."
git checkout master

# Summary line not separated by blank line from next paragraph.
git checkout -b reject6
echo line5 >> file1
git commit -a -m "First line looks okay
but then there's a second line with no separating blank line"
git checkout master

# First line looks like an RT header.
git checkout -b reject7
echo line5 >> file1
git commit -a -m "ticket: 1234"
git checkout master

# Trailing whitespace in diff.
git checkout -b reject8
echo "line5 " >> file1
git commit -a -m "Trailing whitespace"
git checkout master

# Trailing whitespace line in diff.
git checkout -b reject9
echo "" >> file1
git commit -a -m "Trailing whitespace line"
git checkout master

# Space before tab in indentation.
git checkout -b reject10
printf " \tline" >> file1
git commit -a -m "Space before tab in indent"
git checkout master

# Tabs in a file which shouldn't have tabs, missing newlines, and bigredbutton.
git checkout -b reject11
echo "/* -*- mode: c; c-basic-offset: 4; indent-tabs-mode: nil -*- */" > tabs1
printf "\ttab allowed due to bigredbutton\n" >> tabs1
printf "also missing newline" >> tabs1
git add tabs1
git commit -m "Tabs in no-tabs-allowed-file, but

bigredbutton: whitespace"
printf "\n\ttab disallowed due to mode line\n" >> tabs1
printf "\ttab should be allowed here\n" > tabs2
printf "but not the missing newline" >> tabs2
git add tabs1 tabs2
git commit -m "Tabs in no-tabs-allowed file"
git checkout master

push reject1 reject2 reject3 reject4 reject5 reject6 reject7 reject8 reject9 \
    reject10 reject11
