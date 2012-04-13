#!/usr/bin/perl

# Backscatter mitigation for RT.  Reject during SMTP if a recipient is
# an RT address and no ticket number is present.

use strict;
use Sendmail::PMilter qw(:all);
use Sys::Syslog qw(:DEFAULT);

my $sockname = shift @ARGV || die "usage: $0 sockname\n";

my $syslog_prio = "info";
my $syslog_facility = "mail";
my $syslog_opt = "pid";

$< = $> = getpwnam("postfix");
$( = $) = getgrnam("postfix");

openlog "rtmilter", $syslog_opt, $syslog_facility;
syslog $syslog_prio, "starting";

my %cbs;

# List of recipients which require properly formatted subject lines.
my @rcpts = qw(rt rt-krb5 rt-comment rt-kfw rt-kfw-comment milter-test);

# Look for matching recipient in @rcpts.
sub rcptmatch {
    grep {
	my $matched = 0;
	foreach my $r (@rcpts) {
	    $matched = 1, last if /^$r$/i;
	}
    } @_
}

# RCPT TO callback
#
# Build up a recipient list.
$cbs{'envrcpt'} = sub {
    my $ctx = shift;
    my $r = $ctx->getsymval('{rcpt_addr}');
    my $priv = $ctx->getpriv();
    my @envrcpts = defined($priv) ? @{$priv} : ();

    syslog $syslog_prio, "RCPT @_";
    if (defined($r)) {
	$r =~ s/@.*$//;
	push @envrcpts, $r;
	$ctx->setpriv(\@envrcpts);
	syslog $syslog_prio, "envrcpts=@envrcpts";
    }
    return SMFIS_CONTINUE;
};

# Header callback
#
# If we get a "Subject:" header, and one of the special recipients is
# in the recipient list, check the format of the subject header to
# reject it early in case it is not a valid RT subject header.
$cbs{'header'} = sub {
    my ($ctx, $h, $v) = @_;
    my $priv = $ctx->getpriv();
    my @envrcpts = defined($priv) ? @{$priv} : ();

    syslog $syslog_prio, "$h: $v";
    if ($h !~ /^Subject$/i) {
	return SMFIS_CONTINUE;
    }
    if ($v =~ /\[krbdev\.mit\.edu\s+#\d+]/) {
	return SMFIS_CONTINUE;
    }
    if (rcptmatch(@envrcpts)) {
	syslog $syslog_prio, "rejecting subject $v";
	$ctx->setreply(550, "5.7.0", "RT feed requires ticket number");
	return SMFIS_REJECT;
    }
    return SMFIS_CONTINUE;
};

my $milter = new Sendmail::PMilter;

$milter->setconn("local:$sockname");
$milter->register("rtmilter", \%cbs, SMFI_CURR_ACTS);

my $dispatcher = Sendmail::PMilter::prefork_dispatcher(
	max_children => 10,
	max_requests_per_child => 100,
);

$milter->set_dispatcher($dispatcher);
$milter->main();
