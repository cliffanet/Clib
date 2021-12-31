package Clib::Template::Package::Misc::jQuery;

use strict;
use warnings;


sub tag_DATETIME {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('\'result = result + \' . $self->quote(' .
          'Clib::DT::datetime('.$code.')'.
          ') . \';\'' 
        ),
    );
}

sub tag_DATE {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('\'result = result + \' . $self->quote(' .
          'Clib::DT::date('.$code.')'.
          ') . \';\'' 
        ),
    );
}

sub tag_SIZE {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('\'result = result + \' . $self->quote(' .
          'Clib::Num::size('.$code.')'.
          ') . \';\'' 
        ),
    );
}

sub tag_BYTE {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('\'result = result + \' . $self->quote(' .
          'Clib::Num::byte('.$code.')'.
          ') . \';\'' 
        ),
    );
}

sub tag_INTERVAL {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('\'result = result + \' . $self->quote(' .
          'Clib::DT::sec2time('.$code.')'.
          ') . \';\'' 
        ),
    );
}

sub tag_DUMPER {
    my ($prs, %p) = @_;
    
    1;
}

our $Dumper = sub { $Clib::Template::Package::Misc::Html::Dumper->(@_) };

sub tag_CSV {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('\'result = result + \' . $self->quote(' .
          'Clib::Num::csv('.$code.')'.
          ') . \';\'' 
        ),
    );
}



1;
