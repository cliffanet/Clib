package Clib::Template::Package::HTTP::Html;

use strict;
use warnings;



sub tag_SCRIPT_TIME {
    my ($prs) = @_;
    
    $prs->content(
       # '# line: '.$p{line},
        \ ('$self->callback(\'script_time\')->()')
    );
}


sub tag_EINCLUDE {
    my ($prs, %p) = @_;
    
    my $vars = $prs->varsumm(%p);
    
    $prs->content(
       # Заворачиваем в такую конструкцию на случай отключения external
       '{',
       [
            '# line: '.$p{line},
            'my $tmpl = $self->callback(\'external_tmpl\')->('.$p{external}.', '.$p{name}.');',,
            'if ($tmpl) {',
            [
                '($self->{included} ||= {})->{'.$p{external}.' . \'::\' . '.$p{name}.'} ||= $tmpl;',
                '$result .= $tmpl->html('.$vars.');',
            ],
            '}'
       ],
       '}'
    );
}


sub tag_PREF {
    my ($prs, %p) = @_;
    
    my @args = map { $prs->formula_code(formula=> $_) } @{ $p{args} };
    return if grep { !$_ } @args;
    
    $prs->content(
       \ ('$self->callback(\'pref\')->('.join(', ', $prs->quote($p{disp}), @args).')'),
    );
}


sub tag_JSON {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('JSON::XS->new->pretty(0)->canonical(1)->encode('.$code.')'),
    );
}

sub tag_JSONPRETTY {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('$self->dehtml($self->strspace(eval { JSON::XS->new->pretty(1)->canonical(1)->encode('.$code.') }))'),
    );
}

sub tag_JSONTEXT {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    $prs->content(
       \ ('$self->dehtml($self->strspace(eval { JSON::XS->new->pretty(1)->canonical->encode('.$code.') }), 1)'),
    );
}


sub tag_AJAX_INIT {
    my ($prs, %p) = @_;
    
    $prs->content(
       \ '$self->jqueryUpdaterInit()',
    );
}

sub tag_AJAX_SPAN {
    my ($prs, %p) = @_;
    
    my @vname = # Имена переменных, нужны, чтобы в самом слое их использовать, т.к. элемент блочный со своими переменными
        map {
            my $vname = $_->{name} || $p{vardflt} || '_data';
            '$'.$vname;
        }
        @{ $p{vars} };
    my @vopts = # Ссылки на источник переменных, передаваемые в $self->callback(\'ajax_element\')->();
        map {
            my $v = $_;
            my $arg = '';
            if ($v->{formula} && (my $code = $prs->formula_code(formula => $v->{formula}))) {
                $arg = ', arg => '.$code;
            }
            '{ type => '.$prs->quote($v->{type}).', func => '.$prs->quote($v->{func}).$arg.' }'
        }
        @{ $p{vars} };
    
    # Параметры, передаваемые на инициализацию элемента
    # paused будет означать, что не выполнять автообновление, но объект добавить
    # empty будет означать, что вообще не надо генерировать данные при первичном отображении страницы
    my $paused =
        '{ ' .
            join(', ', map { "$_ => 1" } grep { $p{opts}->{$_} } qw/paused empty/) .
        ' }';
    
    my $keypref = '';
    $keypref = '$__UNINAME__ . \'_\' . ' if $p{key_is_rand};
    $prs->content(
       '{',
       [
            '# line: '.$p{line},
            'my ($___span_id, '.join(', ', @vname).') = $self->callback(\'ajax_element_init\')->('.join(', ', $keypref.$prs->quote($p{key}), $paused, @vopts).');',
            \ ($prs->quote('<span id="'.$p{idprefix}).' . $___span_id . '.
               $prs->quote('" data-ajaxelid="').' . $___span_id . '.
               $prs->quote('" data-ajaxkey="'.$p{key}.
                    '" data-ajaxupdater="')),
            \ ($keypref.$prs->quote($p{key})),
        $p{opts}->{hidden} ? (
            \ ($prs->quote('" style="display: none')),
        ) : (),
            \ ($prs->quote('">')),
        $p{opts}->{empty} ? (
        ) : (
            ref($p{content}) eq 'ARRAY' ? @{ $p{content} } : $p{content},
        ),
            \ $prs->quote('</span>'),
       ],
       '}',
    );
}


sub tag_DTABLE {
    my ($prs, %p) = @_;
    
    my $var = $p{vars}->[0] || return;
    my $vname = $var->{name} || $p{vardflt} || '_data';
    my $vcode = '$self->callback(\'dtbl\')->('.$prs->quote($p{dtbl}).')';
    
    $prs->content(
        '# line: '.$p{line},
        'foreach my $'.$vname.' ('.$vcode.') {',
        [ 'my $__DTBL = ' . $prs->quote($p{dtbl}) . ';' ],
        $p{content},
        '}'
    );
}
sub tag_DTABLE_ATTR {
    my ($prs, %p) = @_;
    
    my $code = $p{formula} ? $prs->formula_code(formula=> $p{formula}) : undef;
    
    $prs->content(
        \ (
            $prs->quote(' data-dtbl-item="') .
            ' . $__DTBL . ' .
            $prs->quote('" data-dtbl-url="') .
            ' . $self->callback(\'href_this\')->() . ' .
            $prs->quote('"') .(
                $p{formula} ?
                    ' . '.
                    $prs->quote(' data-dtbl-id="') .
                    ' . ' . $code . ' . ' .
                    $prs->quote('"')
                    : ()
            )
        ),
        #\ ('$self->callback(\'script_time\')->()')
    );
}


1;
