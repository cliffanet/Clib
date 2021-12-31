package Clib::Template::Package::HTTP::jQuery;

use strict;
use warnings;

sub tag_SCRIPT_TIME {
    my ($prs) = @_;
    
    1;
}


sub tag_EINCLUDE {
    my ($prs, %p) = @_;
    
    # ��������� ��������
    return 1;
    
    my $vars = $prs->varsumm();
    
    $prs->content(
       # ������������ � ����� ����������� �� ������ ���������� external
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
    
    # � var ���� ������� ���������� no_jquery_vars, ����� ��� ������������� � ����� �������������� ����������
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
        vars    => {}, # ������������ ������ ���� ��������� ����������
        line    => $p{line},
        content => [
            # ���� ������ ���� $self->{isUpdater} - �� ����� ������������ ��� ���
            # ��� ������������ �������� js-������� ��������� ����
            'if ($self->{isUpdater}) {',
            \ ($prs->quote('function (___key___, '.join(',', @{ $p{varname}||[] }).') {'."\n")),
            \ $prs->quote('    var span = document.getElementById(\''.$p{idprefix}.'\' +  ___key___);'."\n"),
            \ $prs->quote('    if (!span) return;'."\n"),
            # � �� ��������� ���������� ��� �����, ��� ����� �������� ���� ����� html-�����,
            # ����� ��������� ������������ �������, ��������
            # �� ���� ������� ��� ������� ����������, ����� ����� ����� �������, ���� ����� �� ������������
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
            sub {   # �������� ������ � ������, ����� ���������� ������ ��� ������
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
           # ������������ � ����� �����������, �.�. ��� ���� ������� json
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
    
    # ������ ������������ content-����������, ���������� ������ sub_build
    # �� ��� ������� perl-��� ����, ������ ��� ��� � ������ ���������� ��� ������
    # ������ ���, ����� ��� ���������� - ����������� ��� ����, ����� ������ ��� �� �����.
    my @subname = map { $_->{sub} } grep { $_->{sub} } @{$prs->{_level}};
    
    my ($name, $code, $varcall) = $prs->sub_build(
        sub     => $p{id},
        vars    => {}, # ������������ ������ ���� ��������� ����������
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
            vars    => {}, # ������������ ������ ���� ��������� ����������
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
    
    
    # ����� � jquery content ������ �� ������������, ���� ���� ������ ���������
    # ������, ����� �������� content_jquery? �.�. ������������ ������ ��, � �������� content - ������ ���
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
