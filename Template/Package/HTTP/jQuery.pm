package Clib::Template::Package::HTTP::jQuery;

use strict;
use warnings;

sub tag_SCRIPT_TIME {
    my ($prs) = @_;
    
    1;
}


sub tag_EINCLUDE {
    my ($prs, %p) = @_;
    
    # Временная заглушка
    return 1;
    
    my $vars = $prs->varsumm();
    
    $prs->content(
       # Заворачиваем в такую конструкцию на случай отключения external
       '{',
       [
            '# line: '.$p{line},
            'my $tmpl = $self->callback(\'external_tmpl\')->('.$p{external}.', '.$p{name}.');',
            '$result .= $tmpl->jquery('.$vars.') if $tmpl;',
       ],
       '}'
    );
}


sub tag_PREF {
    my ($prs, %p) = @_;
    
    # В var надо сделать обработчик no_jquery_vars, чтобы тут принудительно в перле распарсивались переменные
    my @args = map { $prs->formula_code(formula=> $_) } @{ $p{args} };
    return if grep { !$_ } @args;
    
    $prs->content(
        @args ?
       \ ('\'result = result + String(\' . $self->quote(' .
          '$self->callback(\'pref\')->('.$prs->quote($p{disp}).')'.
          ') . \').format(\' . '.join(' . \', \' . ', @args).' . \');'."\n".'\''
        )
        :
       \ ('\'result = result + \' . $self->quote(' .
          '$self->callback(\'pref\')->('.$prs->quote($p{disp}).')'.
          ') . \';'."\n".'\''
        ),
    );
}


sub tag_JSON {
    my ($prs, %p) = @_;
    
    my $code = $prs->formula_code(formula=> $p{formula}) || return;
    
    my $pretty = $p{pretty} ? 1 : 0;
    
    $prs->content(
       \ ('$self->quote(JSON::XS->new->pretty('.$pretty.')->canonical->encode('.$code.'))'),
    );
}

sub tag_JSONPRETTY { tag_JSON(@_) }

sub tag_JSONTEXT { tag_JSON(@_) }


sub tag_AJAX_INIT {
    my ($prs, %p) = @_;
    
    1;
}
sub tag_AJAX_SPAN {
    my ($prs, %p) = @_;
    
    my @updaterhead = $p{key_is_rand} ?
        (
            \ $prs->quote('ajaxUpdater['),
            \ ( '\'\\\'\' . $__UNINAME__ . \'_\' . ' . $prs->quote($p{key}) . ' . \'\\\'\'' ),
            \ $prs->quote('] = '."\n"),
        ) :
        
        \ $prs->quote('ajaxUpdater['.$prs->quote($p{key}).'] = '."\n");
    #$keypref = '$self->uniname() . \'_\' . ' if $p{key_is_rand};
    
    return $prs->content({
        sub     => $p{id},
        vars    => {}, # Используется только одна дефолтная переменная
        line    => $p{line},
        content => [
            # Если указан флаг $self->{isUpdater} - мы будем использовать наш саб
            # как возвращающий описание js-функции апдейтера слоя
            'if ($self->{isUpdater}) {',
            \ ($prs->quote('function (___key___, '.join(',', @{ $p{varname}||[] }).') {'."\n")),
            \ $prs->quote('    var span = document.getElementById(\''.$p{idprefix}.'\' +  ___key___);'."\n"),
            \ $prs->quote('    if (!span) return;'."\n"),
            # А по умолчанию возвращаем код таким, как будто собираем один общий html-кусок,
            # чтобы корректно отрабатывали инклюды, например
            # Но этот вариант еще требует проработки, когда будут живые примеры, пока нигде не используется
            '} else {',
            \ ($prs->quote('function update_'.$p{id}.'('.join(',', @{ $p{varname}||[] }).') {'."\n")),
            '}',
            \ $prs->quote('    var result = \'\';'."\n"),
            $p{content},
            
            'if ($self->{isUpdater}) {',
            \ $prs->quote('    span.innerHTML=result;'."\n"),
            \ $prs->quote('    if (span.style.display==\'none\') span.style.display=\'block\';'."\n"),
            \ $prs->quote('    if (ajaxUpdateElement) ajaxUpdateElement(span, result);'."\n"),
            $p{content_onchange} ? $p{content_onchange} : (),
            \ $prs->quote('    return result;'."\n"),
            \ $prs->quote('}'),
            '} else {',
            \ $prs->quote('    return result;'."\n"),
            \ $prs->quote('};'."\n"),
            \ $prs->quote('result = result + update_'.$p{id}.'();'."\n"),
            '}',
            sub {   # Поставим маркер в билдер, чтобы определить полное имя метода
                my $self = shift;
                
                $self->updater(
                    @updaterhead,
                    \ ('$self->'.$self->sub_name(@_).'()'),
                    \ $self->quote(';'."\n"),
                );
                
                return '';
            },
        ]
    });
}


=pod
    my @args = map { $prs->formula_code(formula=> $_) } @{ $p{args} };
    return if grep { !$_ } @args;
    
    if ($p{num} < 2) {
        $prs->content_jquery(
           # Заворачиваем в такую конструкцию, т.к. нам надо вызвать json
           '{',
           [
                '# line: '.$p{line},
                'require JSON::XS;',
                'my $opts = $self->callback(\'ajax_opts\')->('.$prs->quote($p{disp}).');',
                '$opts ||= {};',
                '$opts = JSON::XS->new->ascii->pretty(0)->encode($opts);',
                '$result .= '.$prs->quote('ajaxCtrlDefine('.$prs->quote($p{name}).', ') . ' . $self->quote(' .
                    '$self->callback(\'pref\')->('.
                    join(', ', $prs->quote($p{disp}), @args).
                    ')) . ' . $prs->quote(', ').'.$opts.'.$prs->quote(');' . "\n"),
           ],
           '}'
        );
    }
    
    # Вместо стандартного content-форматтера, используем только sub_build
    # он нам создаст perl-код саба, вернет его имя и список переменных для вызова
    # Делаем так, чтобы без усложнений - перечислить все сабы, общий шаблон нам не нужен.
    my @subname = map { $_->{sub} } grep { $_->{sub} } @{$prs->{_level}};
    
    my ($name, $code, $varcall) = $prs->sub_build(
        sub     => $p{id},
        vars    => {}, # Используется только одна дефолтная переменная
        line    => $p{line},
        subname => \@subname,
        content => [
            \ ($prs->quote('function ('.join(',', map { $_->{name} } @{ $p{vars}||[] }).') {')),
            \ $prs->quote('    var result = \'\';'),
            $p{content},
            \ $prs->quote('    return result'),
            \ $prs->quote('}'),
        ],
    );
    
    my $onloadcall = '\'\'';
    
    if ($p{content_onload}) {
        my ($name, $code, $varcall) = $prs->sub_build(
            sub     => $p{id}.'_onload',
            vars    => {}, # Используется только одна дефолтная переменная
            line    => $p{line},
            subname => \@subname,
            content => [
                \ ($prs->quote('function ('.join(',', map { $_->{name} } @{ $p{vars}||[] }).') {')),
                $p{content_onload},
                \ $prs->quote('}'),
            ],
        );
        
        $onloadcall = $prs->quote(', ') . ' . $self->'.$name.'('.$varcall.') . ';
    }
    
    $prs->content_jquery(
        \ ($prs->quote('ajaxBlockDefine('.$prs->quote($p{name}).', '.$prs->quote($p{id}).
                       ', ') . ' . $self->'.$name.'('.$varcall.') . ' . $onloadcall . $prs->quote(");\n"))
    );
    
    
    # Вроде в jquery content совсем не используется, надо этот момент проверить
    # Вообще, зачем вводился content_jquery? т.к. используется только он, а основной content - совсем нет
    $varcall = $p{vars}->[0]->{name} if $p{vars}->[0]->{name}; 
    $prs->content( 
        \ ('\'result = result + '.$p{name}.'('.$varcall.');\'')
    );
    
}
=cut

sub tag_DTABLE {
    my ($prs, %p) = @_;
    
    my $var = $p{vars}->[0] || return;
    my $vname = $var->{name} || $p{vardflt} || '_data';
    my $vcode = $prs->quote('');;#$prs->formula_code(formula=> $var->{formula}) || return;
    
    $prs->content(
        #'# line: '.$p{line},
        \ ($vcode . ' . ' . $prs->quote('.forEach(function('.$vname.') {'."\n")),
        $p{content},
        \ $prs->quote('});'."\n")
    );
}
sub tag_DTABLE_ATTR {
    my ($prs) = @_;
    
    1;
}

1;
