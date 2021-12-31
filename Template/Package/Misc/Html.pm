package Clib::Template::Package::Misc::Html;

use strict;
use warnings;


sub tag_DATETIME {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('Clib::DT::datetime('.$code.')'),
    );
}


sub tag_DATE {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('Clib::DT::date('.$code.')'),
    );
}


sub tag_SIZE {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('Clib::Num::size('.$code.')'),
    );
}


sub tag_BYTE {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('Clib::Num::byte('.$code.')'),
    );
}


sub tag_INTERVAL {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('Clib::DT::sec2time('.$code.')'),
    );
}


sub tag_DUMPER {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('$Clib::Template::Package::Misc::Html::Dumper->('.$code.')'),
    );
}

our $Dumper = sub {
    require Data::Dumper if !$INC{'Data/Dumper.pm'};
    return qq~<span class="debugintext">DBG
        <pre class="debugincode">~.join("\n", Data::Dumper->Dump([@_])).qq~</pre>
</span>~;
};


sub tag_CSV {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('Clib::Num::csv('.$code.')'),
    );
}

1;
