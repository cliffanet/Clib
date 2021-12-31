package Clib::Template::Package::Parser;

use 5.008008;
use strict;
use warnings;

our $VERSION = '1.0';

sub new {
    my ($class, %args) = @_;
    
    my $self = { };
    
    bless $self, $class;
    
    if (ref($args{PLUGIN}) eq 'ARRAY') {
        foreach (@{ $args{PLUGIN} }) {
            $self->plugin_add($_) || return $self;
        } 
    }
    
    return $self;
}

sub error {
    my $self = shift;
    
    if (@_) {
        my $s = shift;
        $self->{_error} = @_ ? sprintf($s, @_) : $s;
        return;
    }
    return $self->{_error} ||= '';
}

sub error_clear {
    my $self = shift;
    $self->{_error} = '';
}

sub debug {
    my $self = shift;
    my $debug = $self->{debug} || return;
    return $debug->(@_);
}

#sub name {}

sub plugin_add {
    my ($self, $pkg) = @_;
    
    $self->error_clear();
    
    my $pkgp = $pkg . '::' . $self->{NAME};
    
    eval "require $pkgp";
    if ($@) {
        $self->error("Can't require pkg %s: %s", $pkg, $@);
        return;
    }
    
    1;
}

sub init {
    my $self = shift;
    
    $self->error_clear();
    
    $self->{_level} = [];
    $self->{_sub} = [];
    
    return $self;
}

=pod
sub code_inherit {
    my ($self, $pname_last) = @_;
    
    return 'sub '.lc($self->{NAME}). ' { '.$pname_last.'::'.lc($self->{NAME}).'(@_); }';
}
=cut

sub level {
    my $self = shift;
    
    $self->{_level}->[0];
}

sub level_new {
    my ($self, %p) = @_;
    
    # Список переменных уровня - либо список хешей, либо сам хеш:
    #   name => имя,может и не быть;
    #   formula => выражение, которое потом будет компилить каждый парсер в код
    if ($p{vars}) {
        if (ref($p{vars}) eq 'HASH') {
            $p{vars} = [$p{vars}];
        }
        elsif (ref($p{vars}) ne 'ARRAY') {
            delete $p{vars};
        }
    }
    if ($p{vars}) {
        # vars - это все переменные слоя, определенные из заголовка
        # Именные переменные слоя
        push @{ $p{varname}||[] }, map { $_->{name} } grep { $_->{name} } @{ $p{vars} };
        $p{varcode} = { map { ($_->{name} =>  $self->formula_code(formula=> $_->{formula})) } grep { $_->{name} } @{ $p{vars} } };
        # Если слой переопределяет переменную "по-умолчанию"
        $p{vardflt} = '_data' if grep { !$_->{name} } @{ $p{vars} };
        # sub может переопределить varn и vardef
    }
    
    # sub - имя функции, в которую этот уровень будет упакован
    # После определения $p{vars} и $p{vardef}, т.к. нам эти данные нужны уже в level_sub
    if (defined $p{sub}) {
        $self->level_sub(\%p);
    }
    else {
        $p{_content} = ($p{content} = []);
    }
    
    
    my $level = { %p };
    unshift(@{ $self->{_level} }, $level);
    
    return $level;
}

sub level_finish {
    my $self = shift;
    
    return if @{ $self->{_level} } < 2;
    
    return shift @{ $self->{_level} };
}

sub level_sub {
    # Определение слоя как саба
    my ($self, $p) = @_;
    
    $p->{content} = { content => [] };
    $p->{_content} = $p->{content}->{content};
    
    $p->{content}->{sub} = $p->{sub};
    
    $p->{content}->{line} = $p->{line} if defined $p->{line};
    
    if (!$p->{nodeepvars}) {
        # Смотрим в глубь до ближайшего sub-уровня, перечисляем все переменные
        my %v = (map { ($_ => 1) } @{ $p->{varname} || [] });
        my $vardflt = $p->{vardflt};
        foreach my $l (@{ $self->{_level} }) {
            foreach my $v (@{ $l->{varname} || [] }) {
                next if $v{$v};
                $v{$v} = 1;
                push @{ $p->{varname} ||= [] }, $v;
            }
            $vardflt ||= $l->{vardflt} if $l->{vardflt};
            
            last if defined $l->{sub};
        }
        $p->{vardflt} = $vardflt if $vardflt;
    }
    
    $p->{content}->{varname} = [ @{ $p->{varname} } ] if $p->{varname};
    $p->{content}->{vardflt} = $p->{vardflt} if $p->{vardflt};
    
    foreach my $v (@{ $p->{varname} || [] }) {
        my $code = ($p->{varcode} || {})->{$v} || next;
        ($p->{content}->{varcode} ||= {})->{$v} = $code;
    }
}

sub level2var {
    # возвращает три основных параметра, отвечающих за видимость переменных на данном уровне:
    # - varname - список имён видимых на данном уровне объявленных переменных
    # - varcode - если переменная на данном уровне не объявлена, а вычисляется
    # - vardflt - виден ли хеш переменных "по умолчанию"
    my ($self, %p) = @_;
    
    my (@code, @name, $dflt, %v);
    foreach my $var (@{ $p{vars}||[] }) {
        my $v = $var->{name} || next;
        next if $v{$v};
        $v{$v} = 1;
        push @name, $v;
        push @code, $v => $self->formula_code(formula=> $var->{formula});
    }
    
    foreach my $l (@{ $p{level_list} || $self->{_level} }) {
        foreach my $v (@{ $l->{varname} || [] }) {
            next if $v{$v};
            $v{$v} = 1;
            push @name, $v;
            if (my $code = ($l->{varcode} || {})->{$v}) {
                push @code, $v => $code;
            }
        }
        $dflt ||= $l->{vardflt} if $l->{vardflt};
        
        last if $p{nodeepvars} || defined($l->{sub});
    }
    
    return
        @name ? (varname => [@name]) : (),
        @code ? (varcode => {@code}) : (),
        $dflt ? (vardflt => $dflt) : ();
}

sub varsumm {
    my ($self, %p) = @_;
    
    my %v = $self->level2var(%p);
    
    my @vars = ();
    
    if (my $vardflt = $v{vardflt}) {
        my $code = '$'.$vardflt;
        push @vars, '( ref('.$code.') eq \'HASH\' ? %{'.$code.'} : () )'
    }
    
    push @vars,
        map { $_->{name}.' => '.($v{varcode}->{$_->{name}} || '$'.$_) }
        grep { $_->{name} }
        @{ $p{vars}||[] };
    
    return join(', ', @vars) if $p{nobraces};
    
    return
        '{ ' .
        join(', ', @vars) .
        ' }';
}

sub content {
    my $self = shift;
	
	my $level = $self->{_level}->[0];
    if (!$level) {
        $self->error("content: Top level error");
        return;
    }
    
    if (@_) {
        push @{ $level->{_content} }, @_;
    }
    
    return $level->{_content};
}

sub content_switch {
    my ($self, $name, $line, $is_multi) = @_;
	
	my $level = $self->{_level}->[0];
    if (!$level) {
        $self->error("content_switch: Top level error");
        return
    }
    my $fname = "content_$name";
    if (!$is_multi && $level->{$fname}) {
        $self->error("content_switch: Duplicate content name '%s'", $name);
        return;
    }
    
    if ($line) {
        $level->{"line_$name"} ||= $line;
    }
    
    if ($is_multi) {
        my $lst = ($level->{$fname} ||= []);
        push @$lst, ($level->{_content} = []);
    }
    else {
        $level->{$fname} = ($level->{_content} = []);
    }
    
    
    return $level->{_content};
}

# Обработчик \лементов контента (по типу содержимого)
my %content_builder = (
    
    INIT  => sub {
        my ($self, $bld) = @_;
        # Код инициализации саба
        $bld->{scalar} = -1;
        return
            "    my \$result = ";
    },
    
    ''  => sub {                                # perl-код
        my ($self, $bld, $content, $indent) = @_;
        
        # Вставка обычного перл кода. Надо проверить состояние _builder_scalar,
        # которая содержит состояние конкатации выходного текста
        my $bscalar = $bld->{scalar};
        $bld->{scalar} = 0;
        if ($bscalar < 0) {                     # До этого было вставлено "$result = " и больше ничего - надо его закрыть
            return "'';\n" . $indent . $content;
        }
        elsif ($bscalar == 0) {                 # До этого было вставлено что-то угодно, но не продолжение result
                                                # (например, начало или конец блока) - любой сторонний код
                                                # Просто пишем новый код
            return "\n" . $indent . $content;
        }
        elsif ($bscalar == 1) {                 # До этого вставлялся такой же скаляр, надо закрыть конкатацию
            return ";\n" . $indent . $content;
        }
        
        return $indent . $content . "\n";
    },
    
    SCALAR  => sub {                            # тоже perl-код, но в виде значений, которые надо запихнуть в result
        my ($self, $bld, $content, $indent) = @_;     # Если это текстовая строка, то она д.б. экранирована
        
        my $bscalar = $bld->{scalar};
        $bld->{scalar} = 1;
        if ($bscalar < 0) {                     # До этого было вставлено "$result = " и больше ничего
            return "\n" . $indent . "    " . $$content;
        }
        elsif ($bscalar == 0) {                 # До этого было вставлено что-то угодно, но не продолжение result
                                                # (например, начало или конец блока) - любой сторонний код
            return "\n$indent\$result .= \n$indent    " . $$content;
        }
        elsif ($bscalar == 1) {                 # До этого вставлялся такой же скаляр, поэтому просто делаем конкатацию с предыдущим
            return "\n$indent  . " . $$content;
        }
        "# !!!!!!!!! %content_builder{SCALAR}: Error processing !!!!!!!!";
    },
    
    ARRAY  => sub {                             # перечень элементов контента более глубокого уровня вложенности
        my ($self, $bld, $cont_list, $indent) = @_;
        
        my $code = '';
        foreach my $content (@$cont_list) {
            $code .= $self->content_builder(ref $content)->($self, $bld, $content, $indent . '    ');
        }
        
        return $code;
    },
    
    HASH  => sub {                              # Более  сложная структура
        my ($self, $bld, $s, $indent) = @_;
        
        if (defined(my $content = $s->{content})) {      # перечень элементов контента более глубокого уровня с доп параметрами
            if (defined($s->{sub})) {
                my $call_code = $self->sub_build(%$s, bld => $bld);
                return $self->content_builder('SCALAR')->($self, $bld, \ $call_code, $indent);
            }
            
            else {
                return $self->content_builder(ref $content)->($self, $bld, $content, $indent . '    ');
            }
        }
        
        elsif (defined $s->{subcall}) {
            # Вызов ранее определенного саба
            my $call_code = $self->sub_call(%$s, bld => $bld);
            return $self->content_builder('SCALAR')->($self, $bld, \$call_code, $indent);
        }
        
        else {
            # ошибка
            return '';
        }
        
    },
    
    CODE    => sub {                              # Возможность оставлять суб-обработчики в билдере
        my ($self, $bld, $sub, $indent) = @_;
        
        return $sub->($self, $bld, $indent);
    },
    
    FINISH  => sub {
        my ($self, $bld) = @_;
        # Для завершения работы _builder_scalar
        # Имитируем вставку обычного perl-кода, но пустого
        return
            $self->content_builder('')->($self, $bld, '', '    ') ."\n" .
            "    return \$result;\n";
    }
);

sub content_builder {
    my $self = shift;
    
    return @_ ? $content_builder{ $_[0] } : %content_builder;
}

sub sub_name {
    # используется только в билдере (нужна ссылка на $bld)
    # определение полного имени функции
    my ($self, $bld) = @_;
    
    # Стэк имен, следуя вложенности блока в блок
    return join('_', @{ $bld->{subname} });
}

sub sub_build {
    # используется только в билдере (нужна ссылка на $bld)
    # собирает в perl-код и регистрирует новую функцию, когда в content встретилось её содержимое (код функции)
    # возвращает perl-код вызова этой функции
    my ($self, %p) = @_;
    
    my $sub = $p{sub} || return;
    #my $vardef = join ', ', map { '$' . $_->{uni} } @{ $p{var}||[] };
    
    my $bld = ($p{bld} ||= { scalar => -1, subname => $p{subname}||[], subrefs => [] });
    
    # Стэк имен, следуя вложенности блока в блок
    push @{ $bld->{subname} }, $sub;
    my $name = $self->sub_name($bld);
    
    # Ссылка на параметры блока (имя для вызова и используемые переменные)
    my $sref = { sub => $sub, name => $name };
    $sref->{varname} = [@{ $p{varname} }] if $p{varname}; # переменные, поступные на том уровне, где билдится функция
    $sref->{vardflt} = $p{vardflt} if $p{vardflt};
    $bld->{subref} = $bld->{subrefs}->[0] || {};
    $bld->{subref}->{$sub} = $sref;                         # Имя определяем на этом уровне,
    unshift @{ $bld->{subrefs} }, { %{ $bld->{subref} } };  # Но при этом дублируем развязанный хеш на следующий,
                                                            # Чтобы определения имен там, оставались локализованными там,
                                                            # Т.е. не были бы видны на более верхних уровнях
    
    my $bscalar = $bld->{scalar};
    
    my $code =  $self->content_builder('INIT')->($self, $bld) .                                 # Инициализация саба
                $self->content_builder(ref $p{content})->($self, $bld, $p{content}, '    ') .   # Код контента
                $self->content_builder('FINISH')->($self, $bld);                                # Завершающий код саба
    
    $bld->{scalar} = $bscalar;
    pop @{ $bld->{subname} };
    
    shift @{ $bld->{subrefs} };
    $bld->{subref} = $bld->{subrefs}->[0];
        
    
    if (!$p{noregister}) {
        # генерируем и регистрируем код функции
        
        # Перечисление аргументов вызова саба
        my $vardef = '';
        $vardef .= ', $'.$_ foreach @{ $p{varname} || [] };
        $vardef .= ', $'.$p{vardflt} if $p{vardflt};
    
        $code =
            "{\n" .
            "    my (\$self$vardef) = \@_;\n".
            $code . 
            "}";
    
        push @{ $self->{_sub} }, join(' ', 'sub', $name, $code);
        
        if (!$p{nouni}) {
            # Зарегистрируем uni-функцию, где в качестве аргументов вызова - только хеш с переменными
            if (@{ $p{varname} || [] }) {
                my @varcall = 
                    map { '$d{'.$_.'}' }
                    @{ $p{varname} || [] };
                push(@varcall, '\%d') if $p{vardflt};
                push @{ $self->{_sub} }, 
                    'sub uni_'.$name." {\n" .
                    "    my (\$self, %d) = \@_;\n" .
                    "    return \$self->$name(".join(', ', @varcall).");\n" .
                    "}";
            }
            elsif ($p{vardflt}) {
                push @{ $self->{_sub} }, 
                    'sub uni_'.$name." {\n" .
                    "    my \$self = shift();\n" .
                    "    return \$self->$name(\{ \@_ \});\n" .
                    "}";
            }
            else {
                push @{ $self->{_sub} }, 
                    'sub uni_'.$name." {\n" .
                    "    my \$self = shift();\n" .
                    "    return \$self->$name();\n" .
                    "}";
            }
        }
    }
    
    return $self->sub_call(%p);
}

sub sub_call {
    # используется только в билдере (нужна ссылка на $bld)
    # генерирует perl-код вызова функции
    # - для этого нужно определить, какие аргументы вызова нужны этой функции,
    # - а так же, какие переменные доступны на том уровне, где производится вызов
    my ($self, %p) = @_;
    
    my $sub = $p{subcall} || $p{sub} || return;
    my $bld = $p{bld} || return;
    $bld->{subref} || return;
    # Всё, что указано в $sref - это параметры того уровня, где билдилась функция (там, где её контент определён)
    # из $sref мы узнаём список аргументов, необходимый для вызова функции (те переменные, которые определены как аргументы вызова этой функции)
    my $sref = $bld->{subref}->{$sub} || return;
    
    my $name = $sref->{name}; # полное имя метода.

    # А одноимённые параметры в %p - это данные на уровне, где эта функция вызывается,
    # из $p{varname} и $p{vardflt} мы определим все переменные, 
    # доступные на этом уровне напрямую (видимые на этом уровне как $var)
    my %var = $p{varname} ? (map { ($_ => 1) } @{ $p{varname} }) : ();
    
    # в крайнем случае - будем использовать vardflt, если он есть
    my $vardflt = $p{vardflt} ? '$'.$p{vardflt}.'->{%s}' : '';
    
    # Дальше надо определиться с переменными вызова
    my @varcall = map {
            ($p{varcode} || {})->{$_} ||    # Указанный в content var-code вызова (на уровне, где эта функция вызывается),
            (
                $var{$_} ?                  # доступная по прямому имени (определена как отдельная переменная на этом уровне)
                    '$'.$_ :
                $vardflt ?
                    sprintf($vardflt, $_) : # либо вызов из дефолтной переменной, если таковая указана
                    'undef'
            )# на худой конец - undef
        } @{ $sref->{varname}||[] };
    push(@varcall, $p{vardflt} ? '$'.$p{vardflt} : '{}') if $sref->{vardflt};
            
    my $varcall = join ', ', @varcall;
    
    return "\$self\->$name($varcall)";
}

sub content_build {
    my ($self, %p) = @_;
	
	my $level = $p{level} || $self->{_level}->[0];
    if (!$level) {
        $self->error("content_build: level error");
        return;
    }
    
    my $content = $level->{content};
    
    #if ((ref($content) ne 'HASH') || !defined(my $sub = $content->{sub})) {
    #    $content = {
    #        sub     => 'main',
    #        content => $content,
    #    };
    #}
    
    my %content = %$content;
    # Если мы подгружаем шаблон через inherited, то не описываем конревые сабы, только блоки
    $content{noregister} = 1 if $p{inherited};
    
    $self->sub_build(%content);
    return join "\n\n", @{ $self->{_sub} };
}

sub quote {
    my ($self, $s, $q) = @_;
    $q ||= '\'';
    $s =~ s/([\\$q])/\\$1/g;
    
    $q = substr($q,0,1);
    
    return $q . $s . $q;
}







sub content_text {
    my ($self, $text) = @_;
    
    return if !defined($text);
    return $self->content()
        if $text eq '';
    
    return $self->content(\ $self->quote($text));
}

sub var {
    my ($self, %p) = @_;
    
    # Преобразование шаблонного имени переменной в perl-код,
    # возвращающий значение элемента из общей структуры входных данных
    
    $p{vpath} || return '';     # шаблонное имя, преобразованное в маршрут следования по структуре входнрых данных
    @{$p{vpath}} || return '';
    my $level_list = $p{level_list} || $self->{_level};
    
    my %ref = (
        HASH    => '->{%s}',
        ARRAY   => '->[%s]',
    );
    
    my ($first, @vpath) = @{$p{vpath}}; # По первому элементу в шаблонном имени мы определяем переменную, из которой будем цеплять всю структуру
    
    my @level = (); # уровни до ближайшего sub-уровня
    foreach my $level (@$level_list) {
        push @level, $level;
        last if defined $level->{sub};
    }
    # Если такая переменная есть с фиксированным именем (именная), то используем ее
    my ($v) = grep { $_ eq $first->{key} } map { @{ $_->{varname}||[] } } @level;
    if (!$v) {
        # Если именной совпадающей нет, тогда используем первую по умолчанию
        ($v) = map { $_->{vardflt} } grep { $_->{vardflt} } @level;
        unshift(@vpath, $first) if $v;
    }
    if (!$v) {
        $self->error("var[%s]: not found named var '%s' and not found default-var", join('.', map { $_->{key} } @{$p{vpath}}), $first->{key});
        return;
    }
    
    my $code = '$' . $v;
    
    # Дальнейшая адресация - безусловная
    $code .= sprintf($ref{$_->{ref}}, $_->{key}) foreach @vpath;
    
    if ($p{dehtml}) {
        $code = $p{br} ? '$self->dehtml('.$code.',1)' : '$self->dehtml('.$code.')';
    }
    if ($p{quote}) {
        $code = '$self->quote('.$code.')';
    }
    
    return $code;
}

my %formula_func = (
        istrue  => sub { '('.$_[0].')' },
        size    => sub { 'scalar(@{ ('.$_[0].')||[] })' },
        keys    => sub { '[ keys %{ ('.$_[0].')||{} } ]' },
        sort    => sub { '[ sort @{ ('.$_[0].')||[] } ]' },
        join    => sub { 'join('.$_[0].', @{ ('.$_[1].')||[] } )' },
        defined => sub { 'defined( '.$_[0].' )' },
        exists  => sub { 'exists( '.$_[0].' )' },
        int     => sub { 'int( '.$_[0].' )' },
        abs     => sub { 'abs( '.$_[0].' )' },
        round   => sub { 'int( sprintf \'%.0f\', ('.$_[0].') )' },
        sprintf => sub { 'sprintf('.join(', ', @_).' )' },
        num02   => sub { 'sprintf(\'%02d\', ('.$_[0].') )' },
        num04   => sub { 'sprintf(\'%04d\', ('.$_[0].') )' },
        reverse => sub { '[ reverse @{ ('.$_[0].')||[] } ]' },
        isarray => sub { '(ref('.$_[0].') eq \'ARRAY\')' },
        ishash  => sub { '(ref('.$_[0].') eq \'HASH\')' },
    );

sub formula_code {
    my ($prs, %p) = @_;
    
    my $s = '';
    foreach my $c (@{ $p{formula} || [] }) {
        if ($c->{type} eq 'sub') {
            my $f = $prs->formula_code(%p, formula => $c->{formula});
            if (!$f) {
                $prs->error("Html::formula_code: build error on code: ", $c->{formula});
                return;
            }
            $s .= '('.$f.')';
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
            $s .= $func->(@f);
        }
        elsif ($c->{type} eq 'op') {
            my $op = $c->{op};
            $s .= ' '.$op.' ';
        }
        elsif ($c->{type} eq 'bool') {
            my $op = $c->{op};
            $op = '==' if $op eq '=';
            $s .= ' '.$op.' ';
        }
        elsif ($c->{type} eq 'un') {
            my $op = $c->{op};
            $s .= $op.' ';
        }
        elsif ($c->{type} eq 'var') {
            $s .= $prs->var(vpath => $c->{vpath});
        }
        elsif ($c->{type} eq 'dig') {
            $s .= ' '.$c->{dig}.' ';
        }
        elsif ($c->{type} eq 'str') {
            $s .= ' '.$c->{quote}.$c->{str}.$c->{quote}.' ';
        }
    }
    
    return $s;
}



1;
