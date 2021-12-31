package Clib::Template::Package::Base::Pdf;

use strict;
use warnings;

use Clib::Template::Package::Base::Html;


sub tag_DEFAULT {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(%p) || return;
    #my $content = '$self->dehtml(' . $code . ')';
    $prs->content(
        #'# line: '.$p{line},
        #\ $content
        \ $code
    );
}

sub tag_RAW {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(%p) || return;
    $prs->content(
        #'# line: '.$p{line},
        \ $code
    );
}

sub tag_TEXT {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(%p) || return;
    #my $content = '$self->dehtml(' . $code . ', 1)';
    $prs->content(
        #'# line: '.$p{line},
        #\ $content
        \ $code
    );
}


sub tag_IF { Clib::Template::Package::Base::Html::tag_IF(@_) }


sub tag_FOREACH {
    my ($prs, %p) = @_;
    $p{content} = [ $prs->chomptxt($p{content}) ];
    return Clib::Template::Package::Base::Html::tag_FOREACH($prs, %p);
}

sub tag_INCLUDE { Clib::Template::Package::Base::Html::tag_INCLUDE(@_) }


1;
