package Clib::Template::Package::Html;

use 5.008008;
use strict;
use warnings;

our $VERSION = '1.0';

use base 'Clib::Template::Package::Parser';


sub init {
    my $self = shift;
    
    $self->SUPER::init(@_);
    
    $self->level_new(sub => 'html', vars => {  }, line => 1);
    
    return $self;
}

1;
