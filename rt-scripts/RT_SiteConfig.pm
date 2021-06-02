# Any configuration directives you include here will override
# RT's default configuration file, RT_Config.pm
#
# To include a directive here, just copy the equivalent statement
# from RT_Config.pm and change the value. We've included a single
# sample value below.
#
# This file is actually a perl module, so you can include valid
# perl code, as well.
#
# The converse is also true, if this file isn't valid perl, you're
# going to run into trouble. To check your SiteConfig file, use
# this comamnd:
#
#   perl -c /path/to/your/etc/RT_SiteConfig.pm

Set($rtname, 'krbdev.mit.edu');
Set($Organization , 'mit.edu');
Set($OwnerEmail , 'ghudson@mit.edu');
Set($LoopsToRTOwner, 0);
Set($CorrespondAddress , 'rt@krbdev.mit.edu');
Set($CommentAddress , 'rt-comment@krbdev.mit.edu');
Set($UseFriendlyToLine, 1);
Set($WebPath, '/rt');
Set($WebDomain, 'krbdev.mit.edu');
Set($WebPort, 443);
Set(@ReferrerWhitelist, qw(krbdev.mit.edu:444));
Set($WebRemoteUserAuth, 1);
Set($WebSecureCookies, 1);
Set( %FullTextSearch,
    Enable     => 1,
    Indexed    => 1,
    Column     => 'ContentIndex',
    Table      => 'AttachmentsIndex',
);
Set($DatabaseHost, "");
#Set(@Plugins,(qw(Extension::QuickDelete RT::FM)));
1;
