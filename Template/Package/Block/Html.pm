package Clib::Template::Package::Block::Html;

use strict;
use warnings;



sub tag_BLOCK {
    my ($prs, %p) = @_;
    
    $prs->content($p{content});
}

sub tag_BLOCKDUP {
    my ($prs, %p) = @_;
    
    $prs->content({
        subcall => $p{name}, # ”казываем вызвать sub
        $prs->level2var(%p),
        line    => $p{line},
    });
}

sub tag_BLOCKINCLUDE {
    my ($prs, %p) = @_;
    
    my $vars = $prs->varsumm(%p, nobraces => 1);
    
    $prs->content(
       '{',
       [
            '# line: '.$p{line},
            'my $tmpl = $self->callback(\'tmpl\')->('.$p{name}.');',
            'if ($tmpl) {',
            [
                '($self->{included} ||= {})->{'.$p{name}.'} ||= $tmpl;',
                '$result .= $tmpl->uni_html_'.$p{block}.'('.$vars.');',
            ],
            '}'
       ],
       '}'
    );
}


1;
