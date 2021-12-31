package Clib::Web::CGI;

use strict;
use warnings;

sub import {
    my $pkg = shift;
    
    
    #my ($init, $request);
    #*{"${callpkg}::ROOT"} = \&ROOT;
    #my $pathRoot = $root;
}

sub event {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    my $method = shift;
    $method || return;
    
    my $n = 0;
    my $callpkg = caller($n);
    $callpkg = caller(++$n) while $callpkg eq __PACKAGE__;
    $callpkg || return;
    $method = "${callpkg}::web_$method";
    
    no strict 'refs';
    
    exists(&$method) || return;
    
    return &$method(@_);
}

sub init {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    event('init');
}

sub request {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    my $prefix = shift;
    
    if (!$ENV{PATH_INFO} && $ENV{TERM} && @::ARGV) {
        $ENV{PATH_INFO} = shift @::ARGV;
    }
    $ENV{PATH_INFO} ||= '/';
    
    my ($body, $status, @hdr) = event('request', $ENV{PATH_INFO});
    
    my %hdr = @hdr;
    if (!$hdr{'Content-type'}) {
        unshift @hdr, 'Content-type' => 'text/html';
    }
    
    if ($status) {
        my ($code, $txt) = split / /, $status, 2;
        
        if (($code > 1) && ($code != 200)) {
            unshift @hdr, Status => $status;
        }
    }
    
    if ($hdr{Location}) {
        undef $body;
    }
    
    while (@hdr > 1) {
        my $hdr = shift @hdr;
        my $val = shift @hdr;
        
        next if $hdr !~ /^[A-Z][a-zA-Z]*(\-[a-zA-Z]+)*$/;
        $val = '' unless defined $val;
        
        print sprintf('%s: %s', $hdr, $val)."\n";
    }
    
    print "\n";
    
    defined($body) || return;
    
    if (ref($body) eq 'CODE') {
        $body = $body->(sub { print @_ });
    }
    
    if (ref($body) eq 'SCALAR') {
        no warnings;
        print $$body;
    }
    else {
        no warnings;
        print $body;
    }
    
    return 1;
}

sub loop {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    init();
    request(@_);
}

1;
