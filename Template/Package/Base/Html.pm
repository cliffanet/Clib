package Clib::Template::Package::Base::Html;

use strict;
use warnings;


sub tag_DEFAULT {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(%p) || return;
    my $content = '$self->dehtml(' . $code . ')';
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
    my $content = '$self->dehtml(' . $code . ', 1)';
    $prs->content(
        #'# line: '.$p{line},
        \ $content
    );
}


sub tag_IF {
    my ($prs, %p) = @_;
    
    my $if = $prs->formula_code(%p) || return;
    
    $prs->content(
        '# line: '.$p{line},
        'if ('.$if.') {',
        $p{content},
        '}'
    );
    
    if (my $elsif = $p{content_elsif}) {
        my @formula = @{ $p{formula_elsif} || [] };
        foreach my $content (@$elsif) {
            $if = $prs->formula_code(%p, formula => shift(@formula)) || return;
            $prs->content(
                'elsif ('.$if.') {',
                $content,
                '}'
            );
        }
    }
    
    if ($p{content_else}) {
        $prs->content(
            '# line: '.$p{line_else},
            'else {',
            $p{content_else},
            '}'
        );
    }
    1;
}


sub tag_FOREACH {
    my ($prs, %p) = @_;
    
    my $vname = $p{vname} || $p{vardflt} || '_data';
    my $vcode = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
        '# line: '.$p{line},
        'foreach my $'.$vname.' (@{ '.$vcode.' || [] }) {',
        $p{content},
        '}'
    );
}

sub tag_INCLUDE {
    my ($prs, %p) = @_;
    
    my $vars = $prs->varsumm(%p);
    
    $prs->content(
       '{',
       [
            '# line: '.$p{line},
            'my $tmpl = $self->callback(\'tmpl\')->('.$p{name}.');',
            'if ($tmpl) {',
            [
                '($self->{included} ||= {})->{'.$p{name}.'} ||= $tmpl;',
                '$result .= $tmpl->html('.$vars.');',
            ],
            '}'
       ],
       '}'
    );
}


1;
