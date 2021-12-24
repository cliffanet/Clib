package Clib::Const;

use strict;
use warnings;

my %const = ();
my $namespace = '';
my $error;

sub namespace {
    $namespace = shift() if @_;
    $namespace = '' unless defined $namespace;
    
    return $namespace;
}
sub error { $error }

sub import {
    my $pkg = shift;
    
    my $noimport = grep { $_ eq ':noimport' } @_;
    if ($noimport) {
        @_ = grep { $_ ne ':noimport' } @_;
        $noimport = 1;
    }
    my $utf8 = grep { $_ eq ':utf8' } @_;
    if ($utf8) {
        @_ = grep { $_ ne ':utf8' } @_;
        $utf8 = 1;
    }
    
    my $namespace = shift;
    $namespace = '' unless defined $namespace;
    
    if (!$const{$namespace}) {
        load($namespace, $utf8 ? (':utf8') : (), @_) || die $error;
    }
    
    $noimport || importer($namespace);
}

sub importer {
    my $namespace = @_ ? shift() : $namespace;
    $namespace = '' unless defined $namespace;
    
    my $callpkg = caller(0);
    $callpkg = caller(1) if $callpkg eq __PACKAGE__;
    my $getLocal = sub { _get($namespace, @_) };
    no strict 'refs';
    *{"${callpkg}::c"} = $getLocal;
    *{"${callpkg}::const"} = $getLocal;
}

sub load {
    my $namespace = shift;
    $namespace = '' unless defined $namespace;
    
    my $utf8 = grep { $_ eq ':utf8' } @_;
    if ($utf8) {
        @_ = grep { $_ ne ':utf8' } @_;
        $utf8 = 1;
    }
    my $root;
    @_ = grep {
            if (/^\:script([0-9])$/) {
                require Clib::Proc;
                $root = Clib::Proc::root_by_script($1);
                0;
            }
            elsif (/^\:lib([0-9])$/) {
                my $level = $1;
                require Clib::Proc;
                my $n = 0;
                my $pkg = caller($n);
                $pkg = caller(++$n) if $pkg eq __PACKAGE__;
                $root = Clib::Proc::root_by_lib($level, $pkg);
                0;
            }
            else {
                1;
            }
        } @_;
    
    my $base = shift() || '';
    
    delete $const{$namespace};
    namespace($namespace);
    
    if (!$base || ($base !~ /^\//)) {
        if (!$root) {
            my $n = 0;
            my $pkg = caller($n);
            $pkg = caller(++$n) if $pkg eq __PACKAGE__;
            no strict 'refs';
            $root = ${"${pkg}::pathRoot"};
        }
        $root = Clib::Proc::ROOT() if !$root && $INC{'Clib/Proc.pm'};
        if ($root) {
            $base = $root . ($base ? '/'.$base : '');
        }
    }
    
    #print "Const load: '$namespace' => $base\n";
    
    if (!$base) {
        $error = 'base dir not defined';
        return;
    }
    
    if ($_[0] && ($_[0] eq ':utf8')) {
        shift;
        $utf8 = 1;
    }
    
    my @file = ();
    
    if ($INC{'Clib/Proc.pm'} && (my $scriptdir = Clib::Proc::SCRIPTDIR())) {
        if (($scriptdir ne $base) && ($scriptdir ne "const/$base")) {
            push @file,
                { file => $scriptdir . '/' . 'const.conf', utf8 => $utf8 },
                { file => $scriptdir . '/' . 'const/const.conf', utf8 => $utf8 };
        }
    }
        
    push @file,
        { file => $base . '/' . 'const.conf', utf8 => $utf8 },
        { file => $base . '/' . 'const/const.conf', utf8 => $utf8 };
    
    if (@_) {
        foreach my $p (@_) {
            if ($p eq ':utf8') {
                $utf8 = 1;
                next;
            }
            push @file, { file => $base . '/' . "const/${p}.conf", key => $p, utf8 => $utf8 };
        }
    }
    elsif (-d $base . '/const') {
        my $dh;
        if (!opendir($dh, $base . '/const')) {
            $error = 'Can\'t read dir `'.$base.'/const`: '.$!;
            return;
        }
        while (defined(my $f = readdir $dh)) {
            next unless $f =~ /^[^\.].*\.conf$/;
            next unless -f $base . '/const/' . $f;
            push @file, { file => $base . '/const/' . $f, key => $f, utf8 => $utf8 };
        }
        closedir $dh;
    }
    
    if ($INC{'Clib/Proc.pm'} && (my $scriptdir = Clib::Proc::SCRIPTDIR())) {
        if (($scriptdir ne $base) && ($scriptdir ne "const/$base")) {
            push @file,
                { file => $scriptdir . '/' . 'redefine.conf', utf8 => $utf8 },
                { file => $scriptdir . '/' . 'const/redefine.conf', utf8 => $utf8 };
        }
    }
    
    push @file,
        { file => $base . '/' . 'redefine.conf', utf8 => $utf8 },
        { file => $base . '/' . 'const/redefine.conf', utf8 => $utf8 };
    
    foreach my $f (@file) {
        my $file = $f->{file};
        next unless -f $file;
        load_file($file, $namespace, $f->{key}, $f->{utf8}) || return;
    }
    
    return $const{$namespace} ||= {};
}

sub load_file {
    my ($file, $namespace, $key, $utf8) = @_;
    
    if (!$file) {
        $error = '$file not defined';
        return;
    }
    
    my $fh;
    if (!open($fh, $file)) {
        $error = 'Can\'t read file `'.$file.'`: '.$!;
        return;
    }
    
    local $/ = undef;
    my $code = <$fh>;
    close $fh;
    
    if (!$code) {
        $error = 'File `'.$file.'` is empty';
        return;
    }
    
    $utf8 = $utf8 ? 'use utf8; ' : '';
    my @c = eval $utf8.'('.$code.')';
    if ($@) {
        $error = 'Can\'t read const file \''.$file.'\': ' . $@;
        return;
    }
    
    my $const = ($const{$namespace} ||= {});
    if (defined $key) {
        delete($const->{$key}) if exists($const->{$key}) && (ref($const->{$key}) ne 'HASH');
        $const->{$key} ||= {};
    }
    if (%$const) {
        _redefine($const, @c);
    }
    else {
        %$const = @c;
    }
    
    undef $error;
    
    $const;
}

sub _redefine {
    my ($c, %h) = @_;
    
    foreach my $k (keys %h) {
        my $v = $h{$k};
        
        if (ref($v) eq 'HASH') {
            _redefine($c->{$k}||={}, %$v);
        }
        elsif (defined $v) {
            $c->{$k} = $v;
        }
        else {
            delete $c->{$k};
        }
    }
    
    1;
}

sub _get {
    my $namespace = shift;
    $namespace = '' unless defined $namespace;
    
    my $c = ($const{$namespace} ||= {});
    while (@_ && defined($c)) {
        my $k = shift;
        $c = ref($c) eq 'ARRAY' ? $c->[$k] : $c->{$k};
    }
    $c;
}
sub get { _get($namespace, @_) }

sub bystr {
    my $path = shift;
    $path || return;
    
    return get(split /\-\>?/, $path);
}
sub parse {
    my $str = shift;
    $str || return $str;
    
    $str =~ s/\$([a-zA-Z0-9_]+(\-\>?[a-zA-Z0-9_]+)*)/bystr($1)/ge;
    
    return $str;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Clib::Const - кодключение конфига или констант из внешнего файла

=head1 SYNOPSIS

    # Подключаем файл const.conf, лежащий в корне проекта
    # и описывающий набор констант, которые мы будем использовать:
    
    use Clib::Const;
    
    # Теперь можем использовать любую сонстанту через функцию c():
    
    print c('myname');

=head1 Типовое подключение

Структура файлов:

=begin text

    bin/
        script
    lib/
        module.pm
    const.conf
    redefine.conf

=end text

Для скрипта C<script>:

    use Clib::Proc qw|script1 lib|;
    use Clib::Const ':utf8';

Если подключение (самый первый вызов C<use Clib::Const>) выполнено из модуля C<module.pm>:

    use Clib::Proc qw|lib1 lib|;
    use Clib::Const ':utf8';

=head1 DESCRIPTION

Обычно для настройки проекта используют обычный perl-файл, в котоорм описывают разные переменные,
а потом подключают этот файл директивой: C<require "my.conf">.

Данный модуль позволяет решить следующие проблемы:

=over 4

=item *

Использовать глобальный конфиг, не зависимо от того, в каком модуле и в каком namespace мы хотим
обратиться к нашим переменным. Например, при использовании в модуле C<MyModule> нам не придётся
писать C<$::myname> или C<$main::myname>. Мы всегда и везде будем использовать конструкцию: C<c('myname')>.

=item *

При необходимости всегда можно использовать несколько разных конфиг-файлов с разными namespace.

=item *

Меньше сложностей с обновлением конфига после его изменения в выполняемом приложении.

=item *

Возможно использование локального переопределения некоторых глобальных констант.

=back

=head1 Подключение конфига

Cтандартное подключение модуля:

    use Clib::Const;

Когда эта строчка встречается самый первый раз в выполняемом коде, загружаются конфиг-файлы.
При всех последующих (например, в разных модулях проекта) - только импорт функций для обращения
к загруженному ранее конфига. Это важно понимать для определения места, откуда будет загружен
конфиг файл.

При этом выполнится загрузка следующих файлов относительно корня проекта:

=over 4

=item *

const.conf

=item *

const/const.conf

=item *

redefine.conf

=item *

const/redefine.conf

=back

Константы, определённые в каждом следующем файле будут переопределять константы, указанные в файлах перед этим.

Опции подключения для определения корня проекта:

=over 4

=item *

:scriptX - используя модуль L<Clib::Proc>, ориентируется относительно
местоположения скрипта, из которого выполнено подключение (самый первый вызов C<use Clib::Const>).

Например, такой вариант вызова означает, что корнем проекта будет директория уровнем выше запущенного скрипта:

    use Clib::Const ':script1';

=item *

:libX - аналогично предыдущему варианту, но относительно расположения модуля, из которого 
выполнено подключение (самый первый вызов C<use Clib::Const>).

=item *

<путь> - Непосредственно указанный абсолютный путь:

    use Clib::Const '/home/myproject';

Если путь указан относительным, то требуется предварительное подключение модуля  L<Clib::Proc>, чтобы определить корень проекта.

=back

Указывать эти опции подключения необязательно, если перед этим был подключен модуль L<Clib::Proc> с соответствующими опциями.

=head1 UNICODE

Чтобы строки в конфиг-файле интерпретировались как UTF-8, необходимо указать опцию подключения C<:utf8>:

    use Clib::Const ':utf8';

=head1 Формат конфиг-файла

Синтаксис идентичен Perl-коду, который надо включить внутрь круглых скобок, например, для определения массива.

Пример:
    
    template_module_dir => 'template.mod',
    template_force_rebuild => 1,
    
    db => {
        host        => 'localhost',
        name        => 'switch',
        user        => 'switch',                # Имя пользователя
        password    => 'nnm',                   # Пароль доступа
    },

В самом начале файла можно (но необязательно) указать строчку:

    #!/usr/bin/perl

Это не повлияет на определение переменных, но позволит некоторым текстовым редакторам корректно подсвечивать текст.

=cut
