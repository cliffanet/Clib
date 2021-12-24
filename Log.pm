package Clib::Log;

use strict;
use warnings;

my @listopts = ();
my %pkg2prefix = ();
my $last_conf = undef;

sub import {
    my $pkg = shift;
    
    my $callpkg;
    
    my $noimport = grep { $_ eq ':noimport' } @_;
    if ($noimport) {
        @_ = grep { $_ ne ':noimport' } @_;
        $noimport = 1;
    }
    
    my $local = grep { $_ eq ':local' } @_;
    if ($local) {
        @_ = grep { $_ ne ':local' } @_;
        $local = 1;
    }
    
    my @pkgprefix = grep { $_ =~ /^pkg-prefix\s*=\s*.+/ } @_;
    if (@pkgprefix) {
        @_ = grep { $_ !~ /^pkg-prefix\s*=\s*.+/ } @_;
        @pkgprefix = map { s/^pkg-prefix\s*=\s*//; $_ } @pkgprefix;
    }
    
    if (grep { $_ eq ':pkg-prefix' } @_) {
        $callpkg ||= caller(0);
        $callpkg = caller(1) if $callpkg eq __PACKAGE__;
        @_ = grep { $_ ne ':pkg-prefix' } @_;
        unshift @pkgprefix, $callpkg;
    }
    
    if (@pkgprefix) {
        $callpkg ||= caller(0);
        $callpkg = caller(1) if $callpkg eq __PACKAGE__;
        $pkg2prefix{$callpkg} = join ' ~ ', @pkgprefix;
    }
    
    if (@_) {
        $callpkg ||= caller(0);
        $callpkg = caller(1) if $callpkg eq __PACKAGE__;
        opts($callpkg, @_);
        @listopts = @_ if !$local;
    }
    elsif (@listopts) {
        $callpkg ||= caller(0);
        $callpkg = caller(1) if $callpkg eq __PACKAGE__;
        opts($callpkg, @listopts);
    }
    
    $noimport || importer();
}

my %default = (
    error       => { null => 1 },
    dumper      => { dump => 1 },
    exception   => { die => 1, dst => ['error'],  }
);
my %pkg2type = ();

my $prebuffer = undef;

my @prefix = ();
my %prefix = ();
my @prefix_permanent = ();

sub opts {
    my $callpkg = shift;
    my $c = {};
    if (ref($_[0]) eq 'HASH') {
        $c = { %{ $_[0] } };
    }
    elsif (@_ && !(@_ % 2)) {
        $c = { @_ }
    }
    elsif ($last_conf) {
        $c = $last_conf;
    }
    elsif ($INC{'Clib/Const.pm'} && $_[0] && !ref($_[0])) {
        $c = Clib::Const::get($_[0]) || Clib::Const::get('logger_default') || Clib::Const::get('log');
        $c = ref($c) eq 'HASH' ? { %$c } : {};
    }
    
    # сохраняем последний загруженный конфиг, он нам пригодится, если при импорте вообще не указано,
    # какой конфиг использовать
    $last_conf = $c if %$c;
    # при этом обязательно его пересобираем, т.к. его содержимое модифицируется в процессе парсинга
    $c = { %$c };
    
    my %flag = (
        map { ($_ => delete $c->{$_}) }
        qw/disable die dump null prebuffer noconsole/
    );
    
    # exception делаем обязательным и по умолчанию в error
    $c->{exception} ||= $default{exception}->{dst};
    
    # Формируем списки dst
    my %type = ();
    foreach my $f (keys %$c) {
        my $dst = $c->{$f} || next;
        $dst = ref($dst) eq 'ARRAY' ? [@$dst] : [$dst];
        
        my $t = ($type{$f} ||= { %{ $default{$f} || {} } });
    
        $t->{dst} = [
            grep { $_ && !ref($_) && ($_ ne '-') }
            @$dst
        ];
    }
    
    # Делаем в два прохода, т.к. иначе не получается корректно разыменовать ссылки на другие dst
    foreach my $f (keys %$c) {
        my $t = $type{$f} || next;
        $t->{dst} = [
            grep { $_ }
            map {
                if (/\$/ && $INC{'Clib/Const.pm'}) {
                    # парсинг переменных из констант
                    $_ = Clib::Const::parse($_);
                }
                if (!/^\// && $INC{'Clib/Proc.pm'} && (my $root = Clib::Proc::ROOT())) {
                    # пишем от текущего корня при указании относительных ссылок
                    $_ = $root . '/' . $_;
                }
                $_;
            }
            # Разыменовываем копирование в другие логи
            map {
                $type{$_} && $type{$_}->{dst} ?
                    @{ $type{$_}->{dst} } :
                    ($_)
            }
            @{ $t->{dst} }
        ];
    }
    
    $prebuffer = [] if $flag{prebuffer};
    
    foreach my $flag (keys %flag) {
        my $fl = $flag{$flag} || next;
        if (ref($fl) ne 'ARRAY') {
            # в качестве флага можно указать либо "1"
            if ($fl && ($fl eq '1')) {
                # тогда флаг будет применён ко всем типам логов
                $_->{$flag} = 1 foreach values %type;
                next;
            }
            else {
                # либо можно перечислить те типы логов, к которым он относится
                $fl = [$fl]
            }
        }
        
        # если мы указали флаг, то принудительно
        # удаляем дефолтное значение этого флага во всех типах логов
        delete($_->{$flag}) foreach values %type;
        
        # и устанавливаем этот флаг только там, где нужно
        foreach my $f (@$fl) {
            my $t = $type{$f} || next;
            $t->{$flag} = 1;
        }
    }
    
    $pkg2type{''} ||= { %type };
    
    return $pkg2type{$callpkg} ||= { %type };
}

sub importer {
    my @base = @_ ? @_ : qw/debug log error exception/;
    
    my $callpkg = caller(0);
    $callpkg = caller(1) if $callpkg eq __PACKAGE__;
    no strict 'refs';
    
    my $types = $pkg2type{$callpkg} || $pkg2type{''} || return;
    my @pkgprefix = exists($pkg2prefix{$callpkg}) ? $pkg2prefix{$callpkg} : ();
    
    foreach my $f (keys %$types) {
        my $type = $types->{$f};
        *{"${callpkg}::$f"} = sub {
            return if $type->{disable};
            
            my $prefix = join ' ~ ', @pkgprefix, grep{ defined($_) && ($_ ne '') } map { $prefix{$_} } @prefix;
            my $s = '';
            if ($type->{dump}) {
                if (!$INC{'Data/Dumper.pm'}) {
                    require Data::Dumper;
                }
                $s = @_ > 1 ? shift() . ': ' : '';
                $s = _str($prefix, join '', $s, Data::Dumper->Dump([@_]));
            }
            else {
                #if ($prefix) { # непонятно, что это и зачем тут было
                #    $s = $prefix . ' > ' . $prefix;
                #}
                $s = _str($prefix, @_);
            }
            
            my @buf = { %$type, str => $s };
            
            if ($prebuffer && (!$type->{prebuffer} || (@$prebuffer >= 1000))) {
                unshift @buf, @$prebuffer;
                undef $prebuffer;
            }
            
            if ($prebuffer) {
                push @$prebuffer, @buf;
                @buf = ();
            }
            
            foreach my $buf (@buf) {
                _to_file($buf->{str}, @{ $buf->{dst} }) if @{ $buf->{dst}||[] };
                
                if ($buf->{die}) {
                    die $buf->{str};
                    return;
                }
                
                if ($ENV{TERM} && !$buf->{noconsole}) {
                    _to_console($buf->{str});
                }
            }
            
            return if $type->{null};
            
            return $s;
        };
    }
    
    foreach my $f (grep { !$types->{$_} } @base) {
        *{"${callpkg}::$f"} = sub {};
    }
    
    *{"${callpkg}::log_prefix"} = \&prefix;
    *{"${callpkg}::log_flag"} = sub { return _flag($types, @_); };
}

sub prefix {
    shift if $_[0] && ($_[0] eq __PACKAGE__);
    
    my $p = { hash => \%prefix, keys => \@prefix };
    bless $p, 'Clib::Log::Prefix';
    
    $p->add(@_);
    
    # Добавление префикса возвращает объект, который позволяет
    # менять этот префикс, а в случае самоуничтожения, удаляет и префикс.
    # Но если мы используем метод prefix в void-контексте,
    # тогда не будем удалять этот префикс совсем.
    push(@prefix_permanent, $p) if !defined(wantarray);
    
    return $p;
}

sub _flag {
    my $types = shift;
    
    my $f = shift() || return; 
    my $flag = shift() || return;
    return unless grep { $flag eq $_ } qw/disable die dump null prebuffer noconsole/;
    
    my $type = $types->{$f};
    
    if (@_) {
        if (shift()) {
            $type->{$flag} = 1;
        }
        else {
            delete $type->{$flag};
        }
    }
    
    return $type->{$flag}||0;
}

sub flag {
    shift if $_[0] && ($_[0] eq __PACKAGE__);
    
    my $callpkg = caller(0);
    $callpkg = caller(1) if $callpkg eq __PACKAGE__;
    my $types = $pkg2type{$callpkg} || $pkg2type{''} || return;
    
    return _flag($types, @_);
}

sub _now { time }

sub _str {
    my ($prefix, $str, @sprintf) = @_;
    $str || return;
    no utf8;
    
    foreach my $s ($str, @sprintf) {
        utf8::is_utf8($s) || next;
        require Encode;
        Encode::_utf8_off($s);
    }
    
    # строка
    $str =~ s/[\n\r]+$//;
    
    # Префикс
    if ($prefix) {
        if (@sprintf) {
            $str = '%s > ' . $str;
            unshift @sprintf, $prefix;
        }
        else {
            $str = $prefix . ' > ' . $str;
        }
    }
    
    # штамп времени
    my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(_now());
    $year = $year % 100; $mon++;
    
    # конечная строка:
    return @sprintf ?
        sprintf("%02d/%02d/%02d, %02d:%02d:%02d: ".$str, $mday, $mon, $year, $hour, $min, $sec, @sprintf) :
        sprintf("%02d/%02d/%02d, %02d:%02d:%02d: %s", $mday, $mon, $year, $hour, $min, $sec, $str);
}
sub _to_console {
    my $str = shift() || return;
    print $str . "\n";
}
sub _to_file {
    my $str = shift() || return;
    
    foreach my $file (grep { $_ } @_) {
        open(my $fh, ">>$file") || next;
        print $fh $str . "\n";
        close $fh;
    }
}

package Clib::Log::Prefix;

sub add {
    my $self = shift;
    @_ || return;
    
    my $h = $self->{hash};
    
    my $n = 1;
    my $k;
    $n++ while exists $h->{ $k = 'n'.$n };
    
    my $s = shift();
    $s = sprintf($s, @_) if @_;
    if (utf8::is_utf8($s)) {
        require Encode;
        Encode::_utf8_off($s);
    }
    $h->{ $k } = $s;
    
    push @{ $self->{keys} }, $k;
    
    return $self->{key} = $k;
}

sub set {
    my $self = shift;
    
    my $k = $self->{key} || return;
    my $h = $self->{hash};
    exists( $h->{ $k } ) || return;
    
    my $s = shift();
    $s = sprintf($s, @_) if @_;
    $h->{ $k } = $s;
}

sub del {
    my $self = shift;
    
    my $k = $self->{key} || return;
    my $h = $self->{hash};
    exists( $h->{ $k } ) || return;
    
    delete $h->{ $k };
    @{ $self->{keys} } = grep { $_ ne $k } @{ $self->{keys} };
    
    1;
}

DESTROY { shift->del() }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Clib::Log - Обеспечивает логирование в файл и/или в консоль

=head1 SYNOPSIS
    
    use Clib::Log;
    
    log('text message');
    debug('debug message');

В логах будет текст:

=for text

    24/12/21, 04:03:07: text message
    24/12/21, 04:03:08: debug message

=head1 Типовое подключение

Структура файлов:

=begin text

    bin/
        script
    const.conf
    redefine.conf
    

=end text

В файле C<const.conf>:

    logPath => "/var/log/myproject",
    log_myproject => {
        log     => '$logPath/messages.log',
        debug   => 'log',
        error   => ['$logPath/error.log', 'log'],
    },

Для скрипта C<script>:

    use Clib::Proc qw|script1 lib|;
    use Clib::Const ':utf8';
    use Clib::Log 'log_myproject';

=head1 DESCRIPTION

Формирует интерфейс для записи логов в файл(ы). В указанном примере сообщения, будут 
направлены в файлы в зависимости от типа сообщения:

=over 4

=item *

c<log(...)> - в файл "/var/log/myproject/messages.log";

=item *

c<debug(...)> - туда же, куда пишет c<log(...)>: т.е. в файл "/var/log/myproject/messages.log";

=item *

c<error(...)> - в файл "/var/log/myproject/error.log",
и продублирует туда же, куда пишет c<log(...)>:
т.е. в файл "/var/log/myproject/messages.log";

=back

=head1 Синтаксис вызова функций

Эквивалентен вызову функции C<sprintf(...)>:

    log('Hello, %s!', $name);

=head1 Опции подключения

Cтандартное подключение модуля:

    use Clib::Log;

Если подключен Clib::Const, путь для файлов логов будет взят из хеша C<log>, например:

    log => {
        log     => '$logPath/messages.log',
        debug   => 'log',
        error   => ['$logPath/error.log', 'log'],
    },

Здесь мы определили путь для функции c<log(...)>. Для функции c<debug(...)> велено использовать тот же путь,
что и для c<log(...)>. А для c<error(...)> указан вариант, когда мы одной строчкой пишем в два разных файла.

=head2 Формат "назначения"

В качестве пути, куда писать логи, можно указать:

=over 4

=item *

Имя файла

=item *

Перенаправление - если в качестве "назначения" указано: log, error и т.л., то путь к файлу назначения будет взят оттуда.

=item *

"-" (минус) - писать логи только в консоль, в файл логирования не будет.

=back


=head2 Опции, доступные только в use-прагме

=over 4

=item *

c<:local> - указывает, что любые настройки подключения C<Clib::Log>, указанные при подключении в нашем
текущем рабочем модуле считать локальными. Без этого флага любая опция импорта модуля будет влиять глобально
на весь запущенный процесс.

=item *

c<:pkg-prefix> - все функции записи в лог, используемые в нашем текущем рабочем модуле, где мы подключаем C<Clib::Log>,
будут вписывать между временем и строкой в качестве префикса имя нашеего модуля:
    
    package MyPackage;
    
    use Clib::Log ':pkg-prefix';

    log('text message');

В логах будет текст:

=for text

    24/12/21, 04:03:07: MyPackage > text message
    

=item *

c<pkg-prefix=строка> - все функции записи в лог, используемые в нашем текущем рабочем модуле, где мы подключаем C<Clib::Log>,
будут вписывать между временем и строкой в качестве префикса - любую нужную нам строчку:
    
    use Clib::Log 'pkg-prefix=Test';

    log('text message');

В логах будет текст:

=for text

    24/12/21, 04:03:07: Test > text message
    

=back

=head2 Опции, доступные как use-прагме, так и через const для каждой функции

Этот пример установит опцию C<noconsole> для всех функций C<Clib::Log>:

    use Clib::Log 'noconsole';

А так через функционал C<Clib::Const> можно указать эту опцию только для функции C<debug(...)>. В файле const.conf:

    log => {
        log     => '$logPath/messages.log',
        debug   => 'log',
        noconsole => ['debug']
    },

=over 4

=item *

C<disable> - отключает логирование полностью.

=item *

C<die> - вызывает C<die> с указанным текстом.

=item *

C<dump> - в качестве аргументов функции следует передавать переменные, которые с помощью Data::Dumper
будут парситься и отображать своё содержимое в логах.

=item *

C<null> - функция должна возвращать пустой список.
Без этой опции функция возвращает переданную ей строчку, собранную с аргументами применением C<sprintf(...)>

=item *

C<prebuffer> - Функции с этой опцией не будут ничего никуда выводить до тех пор, пока любая из других функций
логирования без этой опции не попробует что-то вывести. При этом будут напечатаны все строки, которые должны были вывестись
с этой опцией.

Например, мы с помощью c<debug(...)> хотим всегда обозначать начало выполнение скрипта. Но не хотим, чтобы эта строчка
писалась в логи, если скрипт выполнился без ошибок. Делаем для c<debug(...)> опцию C<prebuffer>:

    log => {
        log     => '$logPath/messages.log',
        debug   => 'log',
        error   => 'log',
        prebuffer => ['debug']
    },

В коде:

    debug('Script begin');
    open(my $fh, 'text.txt') || error('Can\'t open: %s', $!);

Всякий раз, когда мы запускаем скрипт, и файл 'text.txt' открывается успешно, в логи не будет ничего выводится.
Но если при открытии произойдёт ошибка, то будет выведено две строчки:

=for text

    24/12/21, 04:03:07: Script begin
    24/12/21, 04:03:08: Can't open: No such file or directory
    

=item *

C<noconsole> - не будет выводить логи в консоль. Без этого флага любая функция, если для неё указан вывод в файл,
а скрипт запущен в консоли, то лог-строка будет выведена и в файл и в консоль. Этот флаг отключает вывод в консоль.

=back

=head1 Дополнительные префиксы

Функция C<log_prefix(...)> добавит дополнительный префикс в лог-строчки при необходимости.

=head2 C<log_prefix(...)> в void-контексте

Префикс будет добавлен насовсем:

    log('Message 1');
    log_prefix('User test');
    log('Message 2');

Будет выведено:

=for text

    24/12/21, 04:03:07: Message 1
    24/12/21, 04:03:08: User test > Message 2
    

=head2 C<log_prefix(...)> в scalar-контексте

Удобно, когда нам надо ограничить работу префикса областью видимости:

        log('Message 1');
        {
            my $log = log_prefix('User test');
            log('Message 2');
        }
        log('Message 3');

    Будет выведено:

=for text

    24/12/21, 04:03:07: Message 1
    24/12/21, 04:03:08: User test > Message 2
    24/12/21, 04:03:09: Message 3
    

=cut
