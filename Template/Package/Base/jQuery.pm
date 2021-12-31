package Clib::Template::Package::Base::jQuery;

use strict;
use warnings;


sub tag_DEFAULT {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(%p) || return;
    my $content = '\'result = result + dehtml(\' . '.$code.'.\');\''."\n";
    $prs->content(
        #'# line: '.$p{line},
        \ $content
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
    my $content = '\'result = result + dehtml(\' . '.$code.'.\', 1);\''."\n";
    $prs->content(
        #'# line: '.$p{line},
        \ $content
    );
}


sub tag_IF {
    my ($prs, %p) = @_;
    
    my $if = $prs->formula_code(%p) || return;
    
    $prs->content(
        #'# line: '.$p{line},
        \ ($prs->quote('if (').' . '.$if.' . '.$prs->quote(') {'."\n")),
        $p{content},
        \ $prs->quote('}'."\n")
    );
    
    if (my $elsif = $p{content_elsif}) {
        my @formula = @{ $p{formula_elsif} };
        foreach my $content (@$elsif) {
            $if = $prs->formula_code(%p, formula => shift(@formula)) || return;
            $prs->content(
                \ ($prs->quote('else if (').' . '.$if.' . '.$prs->quote(') {'."\n")),
                $content,
                \ $prs->quote('}'."\n")
            );
        }
    }
    
    if ($p{content_else}) {
        $prs->content(
            #'# line: '.$p{line_else},
            \ $prs->quote('else {'."\n"),
            $p{content_else},
            \ $prs->quote('}'."\n")
        );
    }
    
    1;
}

sub tag_FOREACH {
    my ($prs, %p) = @_;
    
    my $vname = $p{vname} || $p{vardflt} || '_data';
    my $vcode = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
        #'# line: '.$p{line},
        \ ($vcode . ' . ' . $prs->quote('.forEach(function('.$vname.') {'."\n")),
        $p{content},
        \ $prs->quote('});'."\n")
    );
}

sub tag_INCLUDE {
    my ($prs, %p) = @_;
    
    my $vars = $prs->varsumm(%p);
    
    $prs->content(
       # '# line: '.$p{line},
        \ ('$self->callback(\'tmpl\')->('.$p{name}.')->jquery('.$vars.')')
    );
}

1;
