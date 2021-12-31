package Clib::Template::Package::jQuery;

use 5.008008;
use strict;
use warnings;

our $VERSION = '1.0';

use base 'Clib::Template::Package::Parser';



use Clib::Template::Package::Html;sub init {
    my $self = shift;
    
    $self->SUPER::init(@_);
    
    $self->level_new(sub => 'jquery', vars => {  }, line => 1);
    
    #$self->{_content_jquery} = [];
    
    $self->{_updater} = [];
    
    return $self;
}


sub content_text {
    my ($self, $text) = @_;
    
    return if !defined($text);
    return $self->content()
        if $text eq '';
        
    if ($self->{_level}->[0]->{content_onchange}) {
        return $self->content(\ $self->quote($text."\n"));
    }
                           
    $text = $self->quote($text, "'\"");
    $text =~ s/\r?\n/\\n/g; # Помимо стандартного экранирования кавычек надо заменить символы перехода строки на их симантический символ
    
    return $self->content(\ $self->quote('result = result + '.$text.';'."\n"));
}

sub var {
    my ($self, %p) = @_;
    
    # Преобразование шаблонного имени переменной в perl-код,
    # возвращающий значение элемента из общей структуры входных данных
    
    $p{vpath} || return '';     # шаблонное имя, преобразованное в маршрут следования по структуре входнрых данных
    @{$p{vpath}} || return '';
    my @lvl = @{ $self->{_level} };
    
    # Особенность jQuery модуля в том, что мы в sub генерим javascript-function,
    # на входе у которой всегда один параметр, т.е. если на стадии прорисовки
    # у нас не оказалось значения во входных данных, дойдя до верхней переменной саба,
    # то в javascript - мы уже сгенерим строковое значение этой переменной, т.е. оно станет статичным
    
    my %ref = (
        HASH    => '.%s',
        ARRAY   => '[%s]',
    );
    
    my ($first, @vpath) = @{$p{vpath}}; # По первому элементу в шаблонном имени мы определяем переменную, из которой будем цеплять всю структуру
    my ($v, $vdef);
    while (my $lvl = shift @lvl) {
        foreach my $v1 ( @{ $lvl->{vars}||[] } ) {
            $vdef = $v1 if !$vdef && !defined($v1->{name});
            next if !defined($v1->{name}) || ($v1->{name} ne $first->{key});
            $v = $v1;
            @lvl = ();
            last;
        }
        if ($lvl->{sub}) {
            # Верхний уровень в сабе, остальные уровни обрабатываем перлом
            last;
        }
    }
    
    if (!$v && $vdef) {
        $v = $vdef;
        unshift @vpath, $first;
    }
    
    my $code = '';
    if ($v) {
        # Нашли фиксированную (именную) переменную или переменную по умолчанию в пределах саба
        # Используем JS-обращение
        $code = $v->{name}||$v->{defname}||'_data';
        # Дальнейшая адресация - безусловная
        $code .= sprintf($ref{$_->{ref}}, $_->{key}) foreach @vpath;
        # Обрамление кавычками для формирования perl-кода
        if ($p{dehtml}) {
            $code = '\'dehtml(' . $code . ($p{br} ? ',1)\'' : ')\'');
        }
        else {
            $code = '\'' . $code . '\'';
        }
    }
    elsif (@lvl) {
        # Не нашли нужной нам переменной в пределах саба, ищем внешнюю уже перлом
        $code = $self->SUPER::var(level_list => \@lvl, vpath => $p{vpath}) || return;
        $code = '$self->quote(' . $code . ')';
    }
    
    return $code;
}



my %formula_func = (
        istrue  => sub { $_[0] },
        size    => sub { '\'Array(\'', $_[0], '\').length\'' },
        #keys    => sub { '[ keys %{ '.$_[0].' } ]' },
        #sort    => sub { '[ sort @{ '.$_[0].' } ]' },
    );

sub formula_code {
    my ($prs, %p) = @_;
    
    my @s = ();
    foreach my $c (@{ $p{formula} || [] }) {
        if ($c->{type} eq 'sub') {
            my $f = $prs->formula_code(%p, formula => $c->{formula});
            if (!$f) {
                $prs->error("Html::formula_code: build error on code: ", $c->{formula});
                return;
            }
            push @s,
                '\'(\'',
                $f,
                '\')\'';
        }
        elsif ($c->{type} eq 'func') {
            my $func = $formula_func{ $c->{name} };
            if (!$func) {
                $prs->error("Html::formula_code: function '%s' not defined", $c->{name});
                return;
            }
            my @f = ();
            foreach my $arg (@{ $c->{arg} }) {
                my $f = $prs->formula_code(%p, formula => $arg);
                if (!$f) {
                    $prs->error("Html::formula_code: build error on func-code: ", $arg);
                    return;
                }
                push @f, $f;
            }
            push @s, $func->(@f);
        }
        elsif ($c->{type} eq 'op') {
            my $op = $c->{op};
            $op = '+' if $op eq '.';
            push @s, '\' '.$op.' \'';
        }
        elsif ($c->{type} eq 'bool') {
            my $op = $c->{op};
            $op = '==' if $op eq '=';
            push @s, '\' '.$op.' \'';
        }
        elsif ($c->{type} eq 'un') {
            my $op = $c->{op};
            push @s, '\''.$op.' \'';
        }
        elsif ($c->{type} eq 'var') {
            push @s, $prs->var(vpath => $c->{vpath});
        }
        elsif ($c->{type} eq 'dig') {
            push @s, $prs->quote($c->{dig});
        }
        elsif ($c->{type} eq 'str') {
            push @s, $prs->quote($c->{quote}.$c->{str}.$c->{quote});
        }
    }
    
    return join(' . ', @s);
}


=pod
sub content_build {
    my ($self, $level) = @_;
	
	$level ||= $self->{_level}->[0];
    if (!$level) {
        $self->error("content_build: level error");
        return;
    }
    
    my $content = $level->{content};
    
    if ((ref($content) ne 'HASH') || !defined(my $sub = $content->{sub})) {
        return;
    }
    
    # Определяем дефолтную переменную в самом верхнем сабе
    $content->{vars} = [{  }];
    
    $self->sub_build(
        %$content,
        content => $self->content_jquery,
    );
    
    return join "\n\n", @{ $self->{_sub} };
}
=cut

sub content_build {
    my $self = shift;
	
	$self->SUPER::content_build(@_);
    
    $self->updater_build();
    
    return join "\n\n", @{ $self->{_sub} };
}


sub updater {
    my $self = shift;
    
    if (@_) {
        push @{ $self->{_updater} }, @_;
    }
    
    return $self->{_updater};
}

sub updater_build {
    my $self = shift;
    
    $self->sub_build(
        sub     => 'jqueryUpdaterInit',
        varname => ['by_child'], # Используется только одна дефолтная переменная
        content => [
            '$result .= $self->SUPER::jqueryUpdaterInit(1) if $self->SUPER::istmpl();',
            '$self->{isUpdater} = 1;',
            @{ $self->updater },
            'delete $self->{isUpdater};',
            'return $result if $by_child;',
            'foreach my $tmpl (values %{ $self->{included} }) {',
            [
                '$result .= $tmpl->jqueryUpdaterInit();'
            ],
            '}',
            'if (@_ == 1) {', # В корневом вызове делаем основную инициализацию
            'my $opt = $self->callback(\'ajax_opt\')->();',
            \ (
                $self->quote('ajaxUpdaterInit(\'').
                ' . $opt->{key} . '.
                $self->quote('\', \'').
                ' . $opt->{url} . '.
                $self->quote('\');'."\n")),
            '}',
        ],
    );
}

1;
