package Clib::Template::Package::Block::jQuery;

use strict;
use warnings;


sub tag_BLOCK {
    my ($prs, %p) = @_;
    
    $prs->content(
        \ ($prs->quote('function ('.join(',', @{ $p{varname}||[] }).') {')),
        \ $prs->quote('    var result = \'\';'),
        $p{content},
        \ $prs->quote('    return result'),
        \ $prs->quote('}'),
    );
}


sub tag_BLOCKDUP {
    my ($prs, %p) = @_;
    
    return 1;
}

1;
