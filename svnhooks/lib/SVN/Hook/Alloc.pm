use strict;
use warnings;

package SVN::Hook::Alloc;
our $VERSION = '0.27';
use File::Temp;

use constant ALLOC_PROP => 'svn-hook-alloc:var';

sub new {
    my ($class, $config) = @_;
    bless $config, $class;
}

sub new_with_perlfile {
    my ($class, $file) = @_;
    my $config = do $file or die $!;
    return $class->new($config);
}

sub get_txn_prop {
    my ($self, $repospath, $txnname, $prop) = @_;
    open my $fh, join(' ', $self->{svntxnprop}, $repospath, $txnname, $prop, ' |')
        or die "Can't run svntxnprop: $!";
    local $/;
    return <$fh>;
}

sub set_txn_prop {
    my ($self, $repospath, $txnname, $prop, $val) = @_;

    system($self->{svntxnprop}, $repospath, $txnname, $prop, $val)
        and die "can't run svntxnprop: $!";
}


sub pre_commit {
    my ($self, $repospath, $txnname, $callback) = @_;
    my $output = `$self->{alloc_cmd}`;
    die "$self->{alloc_cmd}: $!\n" if $?;
    chomp $output;

    $self->set_txn_prop($repospath, $txnname, ALLOC_PROP, $output);
    $callback->($self, $output) if $callback;

    return 0;
}

sub get_alloced_prop {
    my ($self, $repospath, $rev) = @_;

    open my $fh, join(' ', $self->{svnlook}, 'propget', $repospath, '--revprop', '-r', $rev, ALLOC_PROP, ' |')
        or die "Can't run svnlook: $!";
    die $! if $?;
    local $/;
    return <$fh>;
}

sub set_revprop {
    my ($self, $repospath, $rev, $prop, $val) = @_;
    my $fh = File::Temp->new;
    print $fh $val;
    system($self->{svnadmin}, 'setrevprop', $repospath, '-r', $rev, $prop, $fh)
        and die "can't run svnadmin: $!";


}

sub get_revprop {
    my ($self, $repospath, $rev, $prop) = @_;
    open my $fh, join(' ', $self->{svnlook}, 'propget', $repospath, '-r', $rev, '--revprop', $prop, ' |') or die "Can't run svnlook: $!";
    local $/;
    return <$fh>;
}

sub post_commit {
    my ($self, $repospath, $rev) = @_;

    my $var = $self->get_alloced_prop($repospath, $rev) or return;

    $self->set_revprop($repospath, $rev, ALLOC_PROP, '');

    if (my $pattern = $self->{alloc_variable}) {
        my $log = $self->get_revprop($repospath, $rev, 'svn:log');
        if ( $log =~ s/\Q$pattern/$var/g ) {
            $self->set_revprop($repospath, $rev, 'svn:log', $log);
        }
    }

    if ( my $post_cmd = $self->{post_cmd} ) {
        if (my $pattern = $self->{alloc_variable}) {
            $post_cmd =~ s/\Q$pattern/$var/g;
        }
        $post_cmd =~ s/\$revision/$rev/g;
        system($post_cmd); # XXX: error checking;
    }

    return 0;
}


1;


