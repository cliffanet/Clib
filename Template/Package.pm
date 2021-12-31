package Clib::Template::Package;

use 5.008008;
use strict;
use warnings;

our $VERSION = '1.0';


=head1 NAME

Clib::Template::Package - Шаблонизатор, преобразовывает шаблон в Perl-модуль и затем подсоединяет
                его к проекту. Получение данных происходит через вызов полученных методов.

=head1 SYNOPSIS

    use strict;
    use Clib::Template::Package;
    
    my $p = Clib::Template::Package->new(FilesPath => "./html");
        
    my $data = {
        name        => 'Menu',
        list        => [{ id => 1, name => 'item1' }, { id => 2, name => 'item2' }],
    };
    
    print $p->Template('menu', $data);
    
=head1 DESCRIPTION

Преобразует шаблон в perl код и исполняет его.
Сам шаблон преобразуется в метод _root, которому на вход подается $data (может бы только хешем).
Все вставки преобразуются в обращение к $data. Циклы - в foreach.
Инклюды - в require + вызов метода _root (если включаемый шаблон еще не компилировался, то это делается принудительно).

=head1 Методы класса

=over 4

=cut

#========================================================================
#                        -- COMMON TAG STYLES --
#========================================================================
 
my %TAG_STYLE   = (
    'outline'   => [ '\[%',    '%\]', '%%' ],  # NEW!  Outline tag
    'default'   => [ '\[%',    '%\]'    ],
    'template1' => [ '[\[%]%', '%[\]%]' ],
    'metatext'  => [ '%%',     '%%'     ],
    'html'      => [ '<!--',   '-->'    ],
    'mason'     => [ '<%',     '>'      ],
    'asp'       => [ '<%',     '%>'     ],
    'php'       => [ '<\?',    '\?>'    ],
    'star'      => [ '\[\*',   '\*\]'   ],
);

our $pattVar = '[a-zA-Z\_][a-zA-Z\_\d]*(?:\.(?:\[\d+\]|[a-zA-Z\_][a-zA-Z\_\d]*))*';
our $pattScalar = '\'(?:\\\\\\\\|\\\\\'|[^\'\\\\]*)\'';


sub new {
    my ($class, %args) = @_;
    
    my $self = { 
        _config => {
            FILE_DIR    => $args{file_dir} || $args{FILE_DIR} || '/home/template',
            FILE_EXT    => $args{file_ext} || $args{FILE_EXT} || 'html',
            MODULE_DIR  => $args{module_dir} || $args{MODULE_DIR} || '',
            CACH_TIMEOUT=> $args{cach_timeout} || $args{CACH_TIMEOUT} || 0,
            PKG_PREFIX  => $args{pkg_prefix} || $args{PKG_PREFIX} || 'Clib::Template::Package::_Files',
            FORCE_REBUILD => $args{force_rebuild} || $args{FORCE_REBUILD} ? 1 : 0,
            USE_UTF8    => $args{use_utf8} || $args{USE_UTF8} ? 1 : 0,
            TAG_STYLE   => ($args{tag_style} || $args{TAG_STYLE}) && $TAG_STYLE{$args{tag_style} || $args{TAG_STYLE}} ? $args{tag_style} || $args{TAG_STYLE} : 'default',
            
        },
        error       => '',
        _cach       => {},
        
        PARSER      => [],
        PLUGIN      => {},
        TAG_WORKER  => {},
        
        CALLBACK    => ref($args{callback}||$args{CALLBACK}) eq 'HASH' ? $args{callback}||$args{CALLBACK} : {},
    };
    
    if ($self->{_config}->{MODULE_DIR}) {
        $self->{_config}->{MODULE_DIR} =~ s/(\/\.\.|\/)+$//;
        my $dir = $self->{_config}->{MODULE_DIR};
        if (!$dir) {
            $! = "MODULE_DIR Wrong (NULL)";
            return;
        }
        if (!(-d $dir)) {
            $! = "MODULE_DIR is Not dir";
            return;
        }
        if (!(grep { $_ eq $dir } @INC)) {
            eval 'use lib '.Clib::Template::Package::_Files->quote($dir).';';
        }
    }
    
    bless $self, $class;
    
    $self->{_config}->{PKG_PREFIX} =~ s/\:+$//;
    
    $self->{debug} = $args{debug} if ref($args{debug}) eq 'CODE';
    
    $self->{CALLBACK}->{tmpl} ||= sub { return $self->tmpl(@_) };
    
    return $self;
}

sub error {
    my $self = shift;
    
    if (@_) {
        my $s = shift;
        $self->{error} = @_ ? sprintf($s, @_) : $s;
        return;
    }
    
    return $self->{error};
}

sub debug {
    my $self = shift;
    my $debug = $self->{debug} || return;
    return $debug->(@_);
}

sub parser_add {
    my ($self, $class) = @_;
    
    if (!$class) {
        $self->error("parser_add: name or class not defined");
        return;
    }
    
    my $name;
    if ($class !~ /\:\:/) {
        $name = $class;
        $class = "Clib\:\:Template\:\:Package\:\:$class";
    }
    
    eval "require $class";
    if ($@) {
        $self->error("parser_add: Can't require class %s: %s", $class, $@);
        return;
    }
    
    if (!defined($name) && !defined($name = $class->name())) {
        $self->error("parser_add: unknown name for class %s", $class);
        return;
    }
    
    my $prs = $class->new();
    $prs->{NAME} = $name;
    $prs->{CONFIG} = { %{ $self->{_config} } };
    if (my $err = $prs->error) {
        $self->error("parser_add[%s]: %s", $name, $err);
        return;
    }
    
    $prs->{debug} = $self->{debug} if $self->{debug};
    
    foreach my $plg (keys %{ $self->{PLUGIN} }) {
        if (!$prs->plugin_add($plg)) {
            $self->error("parser_add[%s]: plugin_add[%s]: %s", $name, $plg, $prs->error);
            return;
        }
    }
    
    push @{ $self->{PARSER} }, $prs;
}

sub plugin_add {
    my ($self, $plg) = @_;
    
    if (!$plg) {
        $self->error("plugin_add: name or class not defined");
        return;
    }
    
    if ($plg !~ /\:\:/) {
        $plg = "Clib\:\:Template\:\:Package\:\:$plg";
    }
    
    if ($self->{PLUGIN}->{$plg}) {
        $self->error("plugin_add: duplicate plugin '%s'", $plg);
        return;
    }
    
    eval "require $plg";
    if ($@) {
        $self->error("plugin_add: Can't require pkg %s: %s", $plg, $@);
        return;
    }
    
    my $plugin = ($self->{PLUGIN}->{$plg} = {});
    my $tag_wrkr = $self->{TAG_WORKER};
    
    my $tagelh = ($self->{TAG_ELEMENT} ||= {});
    my $tagblh = ($self->{TAG_END} ||= {});
    
    if (my @tag = eval "\@${plg}::SINGLE") {
        foreach my $tag (@tag) {
            my $wrkrMain = eval "\\\&${plg}::tag_${tag}";
            $tag_wrkr->{$tag} = sub {
                my ($slf, $line, $t, $head) = @_;
                
                my @ret = $wrkrMain->($slf, $line, $head);
                @ret || return;
                
                foreach my $prs (@{ $self->{PARSER} }) {
                    my $name = $prs->{NAME};
                    my $worker = eval "\\\&${plg}::${name}::tag_${tag}";
                    $worker->($prs, @ret);
                }
                
                1;
            };
        }
    }
    
    
    if (my %tag = eval "\%${plg}::BLOCK") {
        foreach my $tag (keys %tag) {
            my $wrkrMain = eval "\\\&${plg}::tag_${tag}";
            $tag_wrkr->{$tag} = sub {
                my ($slf, $line, $t, $head) = @_;
                
                my %level = ( method => lc($tag), tag => $tag, data => '', line => $line );
                
                $wrkrMain->($slf, $line, $head, \%level) || return;
                
                foreach my $prs (@{ $self->{PARSER} }) {
                    my $name = $prs->{NAME};
                    my $worker = eval "\\\&${plg}::${name}::tag_${tag}";
                    $prs->level_new(%level, worker => $worker);
                }
                
                1;
            };
            
            foreach my $tagel (@{ $tag{$tag}->{ELEMENT}||[] }) {
                my $wrkrEl = eval "\\\&${plg}::tag_${tag}_${tagel}";
                my $opts = $tag{$tag}->{$tagel};
                
                ($tagelh->{$tagel} ||= {})->{$tag} = sub {
                    my ($slf, $line, $t, $head, $prs, $level) = @_;
                    
                    my $is_multi = $opts && $opts->{is_multi} ? 1 : 0;
                    if (!$is_multi && defined($level->{lc $tagel})) {
                        $slf->error("parse line %d: secondary '%s'", $line, $tagel);
                        return;
                    }
                    $level->{lc $tagel} = '';
                    if (!$prs->content_switch(lc $tagel, $line, $is_multi) ) {
                        $slf->error("parse line %d[%s]: %s", $line, $prs->{NAME}, $prs->error);
                        return;
                    }
                    
                    1;
                };
                
                $tag_wrkr->{$tagel} ||= sub {
                    my ($slf, $line, $t, $head) = @_;
                    
                    $wrkrEl->($slf, $line, $head) || return;
                    
                    foreach my $prs (@{ $slf->{PARSER} }) {
                        my $level = $prs->level;
                        my $wrkrTagEl = $level ? $tagelh->{$tagel}->{$level->{tag}} : undef;
                        if (!$wrkrTagEl) {
                            $slf->error("parse line %d: %s before %s", $line, $tagel, join(' or ', keys %{ $tagelh->{$tagel} }));
                            return;
                        }
                        
                        $wrkrTagEl->($slf, $line, $t, $head, $prs, $level) || return;
                    }
                    
                    1;
                };
            }
            
            my $end = $tag{$tag}->{END} || 'END';
            my $wrkrEl = eval "\\\&${plg}::tag_${tag}_${end}";
            ($tagblh->{$end} ||= {})->{$tag} = 1;
            
            $tag_wrkr->{$end} ||= sub {
                my ($slf, $line, $t, $head) = @_;
                
                $wrkrEl->($slf, $line, $head) || return;
                
                foreach my $prs (@{ $self->{PARSER} }) {
                    my $level = $prs->level_finish;
                    
                    my $ex = $level ? $tagblh->{$end}->{$level->{tag}} : undef;
                    if (!$ex) {
                        $slf->error("parse line %d: %s before %s", $line, $end, join(' or ', keys %{ $tagblh->{$end} }));
                        return;
                    }
                    
                    my $worker = delete $level->{worker};
                    if (!defined($worker->($prs, %$level))) {
                        $self->error("parse line %d: block(%s) syntax error: %s", $line, $level->{tag}, $prs->error());
                        return;
                    }
                }
                
                1;
            };
            
        }
    }
    
    
    foreach my $prs (@{ $self->{PARSER} }) {
        if (!$prs->plugin_add($plg)) {
            $self->error("plugin_add[%s]: parser[%s]: %s", $plg, $prs->{NAME}, $prs->error);
            delete $self->{PLUGIN}->{$plg};
            return;
        }
    }
    
    1;
}

sub cach {
    my ($self, $name, $testing_timeout) = @_;
    
    my $cach = $self->{_cach}->{$name};
    return $cach if $cach && !$testing_timeout;
    
    my $time = $self->{_config}->{CACH_TIMEOUT} > 1 ? time() : 0;
    return $cach
        if $cach && (($time - $cach->{time}) <= $self->{_config}->{CACH_TIMEOUT});
    
    return $self->{_cach}->{$name} = { time => $time };
}

sub file_read {
    my ($self, $name) = @_;
    
    $self->{error} = "";
    
    if (!$name) {
        $self->error("Empty template name");
        return;
    }
    
    if ($name !~ /^[_a-zA-Z][_\-a-zA-Z0-9]*(\/[_a-zA-Z][_\-a-zA-Z0-9]*)*$/) {
        $self->error("Wrong template name format: %s", $name);
        return;
    }
    
    my $cach = $self->cach($name);
    return $cach->{file_data} if defined $cach->{file_data};
    
    my $fname = sprintf "%s/%s.%s", $self->{_config}->{FILE_DIR}, $name, $self->{_config}->{FILE_EXT};
    
    my $fh;
    if (!open($fh, $fname)) {
        $self->error("Can't open file '%s': %s", $fname, $!);
        return;
    }
    
    local $/;
    $cach->{file_data} = scalar <$fh>;
    close $fh;
    
    return $cach->{file_data};
};
 
sub splitter {
    my ($self, $data, $start, $end, $out) = @_;
    
    my @r = ();
    my $line = 1;
    while ($data =~ /$start/) {
        $data = $';
        my $s = $`;
        push @r, $s;
        $line ++ while $s =~ /\n/g;
        
        # Нашли открывающий тэг
        # Теперь ищем закрывающий.
        # Возможно по пути будут встречаться кавычки - это строки,
        # внутри их последовательности, похожие на закрывающий тэг, надо игнорировать
        my $tag = '';
        while ($data =~ /(?:(')|(")|($end)|(\n))/) {
            $data = $';
            $tag .= $`;
            if ($1) {
                    #return @r, { content => $tag, line => $line, out => $data, error => 'Only opening quote \', closing not found; '.$data };
                if ($data =~ /'/) {
                    $data = $';
                    $tag .= '\'' . $` . '\'';
                }
                else {
                    return @r, { content => $tag, line => $line, out => $data, error => 'Only opening quote \', closing not found; ' };
                }
            }
            elsif ($2) {
                if ($data =~ /"/) {
                    $data = $';
                    $tag .= '"' . $` . '"';
                }
                else {
                    return @r, { content => $tag, line => $line, out => $data, error => 'Only opening quote ", closing not found' };
                }
            }
            elsif ($3) {
                $tag = { content => $tag, line => $line };
                last;
            }
            elsif ($4) {
                $tag .= $4;
                $line++;
            }
            else {
                return @r, { content => $tag, line => $line, out => $data, error => 'Unknown data inside TAG' };
            }
        }
        if (ref($tag) ne 'HASH') {
            return @r, { content => $tag, line => $line, out => $data, error => 'TAG-closing not found' };
        }
        
        push @r, $tag;
    }
    
    push(@r, $data) if $data ne '';
    
    return @r;
}

sub vpath {
    my ($self, $name) = @_;
    
    return if !defined($name);
    
    $name =~ s/\s+$//;
    $name =~ s/^\s+//;
    return if $name eq '';
    
    my @path = ();
    while ($name ne '') {
        if ($name =~ s/^([a-zA-Z\_][a-zA-Z\_\d]*)//) {
            push @path, { key => $1, ref => 'HASH' };
        }
        elsif ($name =~ s/^\[(\d+)\]//) {
            if (!@path) {
                $self->error("variable syntax error near '%s' (first element must not be array)", "[$1]".$name);
                return;
            }
            push @path, { key => int $1, ref => 'ARRAY' };
        }
        else {
            $self->error("variable syntax error near '%s' (waiting element)", $name);
            return;
        }
        
        last if $name eq '';
        
        if ($name !~ s/^ *\. *//) {
            $self->error("variable syntax error near '%s' (waiting dot-splitter)", $name);
            return;
        }
    }
    
    return @path;
}


sub formula_compile {
    my ($self, $str, %p) = @_;
    # Возвращает формулу, разбитую на составляющие:
    # sub   - Вложение в скобках (formula => [])
    # func  - Одна из стандартных функций, работу которой определяет парсер (arg => [])
    # op    - Двухаргументная операция (op => &&|\|\||and|or|==|eq|[><]=?)
    # un    - Унарная операция (op => \!|not)
    # dig   - число (в т.ч. с точкой, dig => число)
    # str   - строка (str => строка без кавычек, quote => используемая кавычка)
    #
    #
    
    # Возможные стандартные функции:
    # istrue- проверка на логическое true
    # size  - размер массива
    # keys  - массив ключей
    # sort  - сортировка массива
    #
    
    #my $lev = []; #  Текущий уровень
    my @lev = ([]); # Стэк уровней
    while ($str ne '') {
        my $prev = @{ $lev[0] } ? $lev[0]->[ @{ $lev[0] }-1 ] : undef; # Предыдущий элемент в уровне
        #$prev = { type => 'sub', formula => $prev } if ref($prev) eq 'ARRAY';
        if ($str =~ s/^\s+//) {
            next;
        }
        elsif ($str =~ s/^\(//) {
            if ($prev && ($prev->{type} ne 'op') && ($prev->{type} ne 'bool') && ($prev->{type} ne 'un')) {
                $self->error("formula syntax error near '%s': subformula must be first or after operation", $&.$str);
                return;
            }
            my $l = { type => 'sub', formula => [] };
            push @{ $lev[0] }, $l;
            unshift @lev, $l->{formula};
        }
        elsif ($str =~ s/^([a-zA-Z][a-z0-9_]*)\s*\(//) {
            my $name = $1;
            if ($prev && ($prev->{type} ne 'op') && ($prev->{type} ne 'bool') && ($prev->{type} ne 'un')) {
                $self->error("formula syntax error near '%s': function must be first or after operation", $&.$str);
                return;
            }
            my $l = { type => 'func', name => $name, arg => [[]]};
            push @{ $lev[0] }, $l;
            unshift @lev, $l->{arg}->[0];
        }
        elsif ((@lev >= 2) && ($str =~ s/^\s*\,\s*//)) {
            # Список параметров - используем только для функции (см блок выше)
            if (!@{ $lev[0] }) {
                $self->error("formula syntax error near '%s': empty subformula", $&.$str);
                return;
            }
            if ($prev && ($prev->{type} eq 'op')) {
                $self->error("formula syntax error near '%s': waiting seccond argument for operation '%s'", $&.$str, $prev->{op});
                return;
            }
            
            my $prev1 = @{ $lev[1] } ? $lev[1]->[ @{ $lev[1] }-1 ] : undef; # Указатель на функцию, для которой мы перечисляем аргументы
            if (!$prev1 || ($prev1->{type} ne 'func')) {
                $self->error("formula syntax error near '%s': comma allowed only in function arguments", $&.$str);
                return;
            }
            
            my $arg = [];
            push @{ $prev1->{arg} }, $arg;
            $lev[0] = $arg;
        }
        elsif ($str =~ s/^\)//) {
            if (@lev < 2) {
                if ($p{multi}) {
                    $str .= ')';
                    last;
                }
                $self->error("formula syntax error near '%s': unwaited symbol ')'", $&.$str);
                return;
            }
            if (!@{ $lev[0] }) {
                $self->error("formula syntax error near '%s': empty subformula", $&.$str);
                return;
            }
            if ($prev && ($prev->{type} eq 'op')) {
                $self->error("formula syntax error near '%s': waiting seccond argument for operation '%s'", $&.$str, $prev->{op});
                return;
            }
            
            shift @lev;
        }
        elsif ($prev && ($prev->{type} =~ /^(dig|str|var|func|sub)$/) &&
               ($str =~ s/^(\+|-|\*|\/|\.)//i)) {
            # минус (-) может быть использован в качестве признака отрицательного числа в булевых выражениях
            # Поэтому чтобы оно не попало сюда, проверяем на $prev
            my $op = $&;
            #if (!$prev || ($prev->{type} !~ /^(dig|str|var|func|sub)$/)) {
            #    $self->error("formula syntax error near '%s': operation with not supported argument", $op.$str);
            #    return;
            #}
            push @{ $lev[0] }, { type => 'op', op => lc $op };
        }
        elsif ($str =~ s/^(&&|\|\||and\b|or\b|==|=|\!=|eq\s|ne\b|[><]=?)//i) {
            my $op = $&;
            if (!$prev || ($prev->{type} !~ /^(dig|str|var|func|sub)$/)) {
                $self->error("formula syntax error near '%s': bool-operation with not supported argument (%s)",
                             $op.$str, $prev? $prev->{type} : '-unknown-');
                return;
            }
            push @{ $lev[0] }, { type => 'bool', op => lc $op };
        }
        elsif ($str =~ s/^(\!|not)//i) {
            my $op = $&;
            if ($prev && ($prev->{type} ne 'op') && ($prev->{type} ne 'bool') && ($prev->{type} ne 'bool')) {
                $self->error("formula syntax error near '%s': unary operation must be first or after op", $op.$str);
                return;
            }
            push @{ $lev[0] }, { type => 'un', op => lc $op };
        }
        elsif ($str =~ s/^$pattVar//o) {
            my $name = $&;
            if ($prev && ($prev->{type} ne 'op') && ($prev->{type} ne 'bool') && ($prev->{type} ne 'un')) {
                $self->error("formula syntax error near '%s': variable must be first or after operation", $name.$str);
                return;
            }
            my $l = { type => 'var', name => $name, vpath => [ $self->vpath($name) ] };
            @{ $l->{vpath} } || return;
            push @{ $lev[0] }, $l;
        }
        elsif ($str =~ s/^\-?\d+(\.\d+)?//) {
            my $dig = $&;
            if ($prev && ($prev->{type} ne 'op') && ($prev->{type} ne 'bool') && ($prev->{type} ne 'un')) {
                $self->error("formula syntax error near '%s': digital must be first or after operation", $dig.$str);
                return;
            }
            my $l = { type => 'dig', dig => $dig };
            push @{ $lev[0] }, $l;
        }
        elsif ($str =~ s/^\'([^\']+|\\\')*\'//) {
            my $s = $&;
            if ($prev && ($prev->{type} ne 'op') && ($prev->{type} ne 'bool') && ($prev->{type} ne 'un')) {
                $self->error("formula syntax error near '%s': str must be first or after operation", $s.$str);
                return;
            }
            $s =~ s/^\'//;
            $s =~ s/\'$//;
            my $l = { type => 'str', str => $s, quote => '\'' };
            push @{ $lev[0] }, $l;
        }
        elsif (!$p{multi}) {
            $self->error("formula syntax error near '%s'", $str);
            return;
        }
        else {
            last;
        }
    }
    
    if (@lev != 1) {
        $self->error("formula syntax error at end: waiting symbol ')'");
        return;
    }
    
    if (@{ $lev[0] } < 1) {
        $self->error("formula syntax error at end: empty formula");
        return;
    }
    
    my $prev = $lev[0]->[ @{ $lev[0] }-1 ]; # Предыдущий элемент в уровне
    if ($prev->{type} eq 'op') {
        $self->error("formula syntax error at end: waiting seccond argument for operation '%s'", $prev->{op});
        return;
    }
    
    return ($lev[0], $str) if $p{multi} && wantarray;
    
    return $lev[0];
}

sub parse {
    my $self = shift;
    my $data = shift;
        
    $_->init() foreach @{ $self->{PARSER} };
    
    @{ $self->{PARSER} } || return '';
    
    my $tag = $TAG_STYLE{$self->{_config}->{TAG_STYLE}} || return;
    
    my $tag_wrkr = $self->{TAG_WORKER};
    my $tag_expr = join '|', keys %$tag_wrkr;
    $self->{TMP} = {};
    foreach my $s ($self->splitter($data, @$tag)) {
        if (ref($s) eq 'HASH') {
            if ($s->{error}) {
                $self->error("parse line %d: %s", $s->{line}, $s->{error});
                return;
            }
            
            $s->{content} =~ s/^\s+//;
            $s->{content} =~ s/\s+$//;
            if ($s->{content} =~ /^($tag_expr)(?:\s+(\S+.*))?$/) {
                # команды интерпретатора
                if (my $sub = $tag_wrkr->{$1}) {
                    $sub->($self, $s->{line}, $1, $2) || return;
                }
            }
            elsif ($s->{content} ne '') {
                if (my $sub = $tag_wrkr->{DEFAULT}) {
                    $sub->($self, $s->{line}, DEFAULT => $s->{content}) || return;
                }
            }
        }
        else {
            foreach my $prs (@{ $self->{PARSER} }) {
                if (!$prs->content_text($s)) {
                    $self->error("content_text[%s]: %s", $prs->{NAME}, $prs->error);
                    return;
                }
            }
        }
    }
    
    foreach my $prs (@{ $self->{PARSER} }) {
        if (my $level = $prs->level_finish) {
            $self->error("parse line %d: not found 'END' after %s", $level->{line}, uc $level->{tag});
            return;
        }
    }
    
    return @{ $self->{PARSER} };
}

sub code {
    my ($self, $name, $pname, %p) = @_;
    
    # $name - имя файла исходного шаблона
    # $pname - название пакета
    
    $p{cname} ||= $name; # Имя шаблона в кеше (под каким именем мы будем его искать в кеше)
    my $cach = $self->cach($p{cname});
    return $cach->{code} if defined $cach->{code};
    
    if (defined $p{data}) {
        use Encode;
        Encode::_utf8_off($p{data});
    }
    my $fdata = defined($p{fdata}) ? $p{fdata} : $self->file_read($name);
    defined($fdata) || return;
    
    my @parser = $self->parse($fdata);
    @parser || return;
    my $time = time();
    
    my $use_utf8 = $self->{_config}->{USE_UTF8} ? "\n        use utf8;" : "";
    
    my @code = (); 
    
    if (!$p{inherited}) {
        # саб, сообщающий, что наш класс - уже класс реального шаблона, а не Clib::Template::Package::_Files
        # Добавляем его только в базовый шаблон,
        # наследники его и так унаследуют (смысла добавлять лишний код нет)
        push @code, 'sub istmpl { 1 }';
    }
    
    foreach my $prs (@parser) {
        my $code = $prs->content_build(%p) || return;
        push @code, $code;
    }
    
    my $sname = (split(/\:\:/, $pname))[-1];
    
    $p{pbase} ||= 'Clib::Template::Package::_Files'; # пакет, от которого будем наследовать наш шаблон-объект
    return $cach->{code} = "
        package $pname;
        
        use strict;
        use warnings;$use_utf8
        use base '$p{pbase}';
        #use Data::Dumper;
        
        our \$COMPILLED = 1;
        our \$DT = $time;
        
        my \$__NAME__ = '$sname';
        my \$__UNINAME__ = \$__NAME__ . '_' . \$DT;
        
        \n".join("\n\n", @code)."
        
        1;\n";
    
}

sub content {
    # функция для отладки парсеров, чтобы во внешнем коде можно было получить полную структуру content
    my ($self, $name, %p) = @_;

    my $fdata = defined($p{fdata}) ? $p{fdata} : $self->file_read($name);
    defined($fdata) || return;
    
    my @parser = $self->parse($fdata);
    @parser || return;
    
    return (@parser > 1) && wantarray ?
        (map { $_->content() } @parser) :
        $parser[0]->content();
}

sub require {
    my ($self, $name, $code_get) = @_;
    
    if (!$name) {
        $self->error("Empty template name");
        return;
    }
    
    my $cach = $self->cach($name, 1);
    
    my $pname = $name;
    $pname =~ s/[^a-zA-Z0-9\_]/_/g;
    $pname = $self->{_config}->{PKG_PREFIX} . '::' . $pname;
    
    if (eval "\$$pname\::COMPILLED") {
        return ($pname, $cach);
    }
    
    my $fname;
    if (my $path = $self->{_config}->{MODULE_DIR}) {
        # Если указана директория
        
        # Переписываем файл
        my @path = split /\:\:/, $pname;
        my $file = pop @path;
        foreach my $p (@path) {
            $path .= "/$p";
            if (!(-d $path) && !mkdir($path)) {
                $self->error("Can't make dir '%s': %s", $path, $!);
                return;
            }
        }
        
        $fname = "$path/${file}.pm";
        if (!$self->{_config}->{FORCE_REBUILD} && (-f $fname)) {
            # Пытаемся закомпилить файл
            my $eval = eval " require $pname; ";
            if (!$eval) {
                $self->error("Can't compile module '%s' (without rebuild): %s", $pname, $@);
                return;
            }
            return ($pname, $cach);
        }
    }
    
    my $code = $code_get->($name, $pname) || return;
    
    $self->{error} = "";
    
    if ($fname) {
        if (!open(FHM, '>', $fname)) {
            $self->error("Can't open file '%s' to rewrite: %s", $fname, $!);
            return;
        }
        print FHM $code;
        print FHM "\n";
        close FHM;
        
        # Пытаемся закомпилить файл
        my $eval = eval " require $pname; ";
        if (!$eval) {
            $self->error("Can't compile module '%s': %s", $pname, $@);
            return;
        }
    }
    
    else {
        # Если директория для модулей не указана, тогда компилим налету
        
        my $eval = eval $code;
        if (!$eval) {
            $self->error("Can't compile module '%s': %s", $pname, $@);
            return;
        }
    }
    
    return ($pname, $cach);
}

sub require_inherit {
    my ($self, $name, @inherit) = @_;
    
    if (!$name) {
        $self->error("Empty template name");
        return;
    }
    
    my $tname = join('--', $name, @inherit);
    
    # Параметры генерации кода
    my %p = (cname => $tname, pbase => 'Clib::Template::Package::_Files');
    if (@inherit) {
        # Если есть, что наследовать, подгружаем этот модуль
        ($p{pbase}) = $self->require_inherit(@inherit);
        # Используем его имя в качестве родителя (наследуем)
        $p{pbase} || return;
        # И помечаем в текущем коде, что у нас есть родительские шаблоны, поэтому
        # не надо описывать в нашем модуле базовые сабы вывода кода - используем их от родителей
        $p{inherited} = 1;
    }
    
    return $self->require($tname, sub { $self->code($name, $_[1], %p) });
}

sub tmpl {
    my ($self, $name, @inherit) = @_;
    
    my ($pname, $cach) = @inherit ?
        $self->require_inherit($name, @inherit) :
        $self->require($name, sub { $self->code(@_) });
        
    $pname || return;
    
    return $cach->{obj} = $pname->new($self->{CALLBACK});
}

sub templ_by_txt {
    my ($self, $name, $txt) = @_;
    
    my ($pname, $cach) = $self->require($name, sub { $self->code($name, $_[1], fdata => $txt) });
        
    $pname || return;
    
    return $cach->{obj} = $pname->new($self->{CALLBACK});
}

package Clib::Template::Package::_Files;

sub new {
    my $class = shift;
    my $callback = shift;
    
    my $self = {};
    bless $self, $class;
    
    $self->{CALLBACK} = $callback || {};
    
    return $self;
}

sub html {
    my $self = shift;
    
    return "test";
}


sub quote {
    my ($self, $s, $q) = @_;
    $s = '' unless defined $s;
    $q ||= '\'';
    $s =~ s/([\\$q])/\\$1/g;
    
    $q = substr($q,0,1);
    
    return $q . $s . $q;
}

sub dehtml {
    my ($self, $s, $make_br, $no_code_replace) = @_;
    $s = '' unless defined $s;
    if ($no_code_replace) {
        $s =~ s/\&(?!\#\d+\;)/\&amp\;/g;
    } else {
        $s =~ s/\&/\&amp\;/g;
    }
    $s =~ s/</\&lt\;/g; $s =~ s/>/\&gt\;/g; $s =~ s/\"/\&quot\;/g;
    #$s =~ s/^[ \r\n\t\f]+//g; $s =~ s/[ \r\n\t\f]+$//g; 
    if ($make_br) { $s =~ s/\n/\<br\>/g; $s =~ s/[\r\n\f\t]//g; }

    return $s;
}

sub strspace {
    my ($self, $s) = @_;
    
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;

    return $s;
}

sub callback {
    my ($self, $name) = @_;
    
    return $self->{CALLBACK}->{$name};
}

sub istmpl { 0 }


1;
