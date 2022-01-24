package Clib::Web::Param;

use strict;
use warnings;


=pod

=encoding UTF-8

=head1 NAME

Clib::Web::Param - Парсинг параметров GET/POST запроса.

=head1 SYNOPSIS
    
    use Clib::Web::Param;
    
    my $p = web_param(prepare => 1);
    
    my $val = $p->raw('param');

=head1 Простые функции

Эти функции не импортируются (вызвать их можно через C<Clib::Web::Param::fff()>).

=cut

sub import {
    my $pkg = shift;
    
    my $noimport = grep { $_ eq ':noimport' } @_;
    if ($noimport) {
        @_ = grep { $_ ne ':noimport' } @_;
        $noimport = 1;
    }
    
    
    return if $noimport;
    
    my $callpkg = caller(0);
    $callpkg = caller(1) if $callpkg eq __PACKAGE__;
    no strict 'refs';
    
    foreach my $f (qw/param cookie/) {
        my $sub = *{$f};
        *{"${callpkg}::web_$f"} = sub { return $sub->(@_); };
        *{"${callpkg}::web_e$f"} = sub { return $sub->(prepare => 1, @_); };
    }
    
    *{"${callpkg}::web_paramerr"} = *err;
}

=head2 url_data($query)

Разбирает строку в формате query-string: field1=val1&fi1ld2=val2...

На выходе: хэш "ключ-значение"

    my %p = Clib::Web::Param::url_data($query)

=cut

sub url_data {
    my $delimiter = $_[1] || '&';
    
    return
        map {
            map { url_decode($_) }
            split (/=/, $_, 2)
        }
        split(/$delimiter/, $_[0]);
}

=head2 data2url(%fields)

Собирает из хеша ключ-значение обратно query-string: field1=val1&fi1ld2=val2...

    my $query = Clib::Web::Param::data2url(
                field1 => 'val1',
                field2 => 'val2',
            );

=cut

sub data2url {
    my @s = ();
    
    while (@_) {
        my $k = url_encode(shift());
        my $v = url_encode(shift());
        push @s, $k . '=' . $v;
    }
    
    return join('&', @s);
}

=head2 url_encode($string)

Преобразует строку $string в URL-формат, где все спецсимволы заменены на формат %xx

    my $url = Clib::Web::Param::url_encode('Hello World');
    
    # $url = 'Hello%20World';

=cut

sub url_encode
{
    my $string = shift;
    
    Encode::_utf8_off($string);
    $string =~ s/([^-.\w ])/sprintf('%%%02X', ord $1)/ge;
    $string =~ tr/ /+/;

    return $string;
}

=head2 url_decode($string)

Обратное преобразование строки из URL-формата, где все спецсимволы заменены на формат %xx

    my $str = Clib::Web::Param::url_decode('Hello%20World');
    
    # $str = 'Hello World';

=cut

sub url_decode
{
    my $string = shift;

    $string =~ tr/+/ /;
    $string =~ s/%([\da-fA-F]{2})/chr (hex ($1))/eg;

    return $string;
}

sub encode {
    my $src = shift;
    my $dst = shift;
    
    require Encode;
            
    return
        map {
            my $v;
            if ($src) {
                $v = Encode::decode($src, $_);
            }
            else {
                $v = $_;
                Encode::_utf8_on($v);
            }
            $dst ? Encode::encode($dst, $v) : $v;
        }
        @_;
}

=head1 Импортируемые функции

=head2 web_paramerr()

Возвращает ошибки при парсинге GET/POST-запросов.

=cut

my $error;
sub err {
    return $error;
}

=head2 web_param(...)

Парсит GET/POST-запрос.

В простом варианте возвращает хеш ключ-значение параметров запроса.

    use Clib::Web::Param;
    
    my %p = web_param();
    
    my $val1 = $p{field1};

Параметры вызова:

=over 4

=item *

Флаг C<prepare> - В этом случае C<web_param(...)> вернёт объект, который позволит
более гибко работать с полученными параметрами.

=item *

C<file> - Хеш, где ключ - имя поля, а значение - что делать в случае,
если под этим полем мы загружаем файл.

Если значение: скаляр - это будет считаться именем файла, в который надо записать данные.

Если значение: ссылка на скаляр - в этот скаляр будут загружены данные этого файла без сохранения на диск.

=back

=cut

sub param {
    my %p = @_;
    
    undef $error;
    
    my $ctype = $p{CONTENT_TYPE} || $ENV{CONTENT_TYPE} || '';
    
    # Кодировка на входе и на выходе
    my $cssrc;
    my $csdst = $p{charset};
    if ($csdst) {
        $csdst = '' if $csdst =~ /^utf(-?8)?$/i;
    }
    if ($ctype =~ /;\s*charset=(.+)$/) {
        $cssrc = $1;
        $cssrc = '' if $cssrc =~ /^utf(-?8)?$/i;
        if ($cssrc && $csdst && (lc($cssrc) eq lc($csdst))) {
           undef $cssrc;
           undef $csdst;
        }
    }
    
    # Определяем входные параметры
    my @data = ();
    
    my $method = $p{REQUEST_METHOD} || $ENV{REQUEST_METHOD} || '';
    
    if ($method =~ /^(get|head)$/i) {
        my $str = defined($p{QUERY_STRING}) ? $p{QUERY_STRING} : $ENV{QUERY_STRING} || '';
        @data = url_data($str);
    }
    elsif ($method =~ /^post$/i) {
        if (!$ctype || ($ctype =~ /^application\/x-www-form-urlencoded/)) {
            local $^W = 0;
            my $stdin = $p{STDIN} || \*STDIN;
            my $clen = defined($p{CONTENT_LENGTH}) ? $p{CONTENT_LENGTH} : $ENV{CONTENT_LENGTH} || 0;
    
            my $data;
            read ($stdin, $data, $clen);
            
            @data = url_data($data);
        }
        elsif ($ctype =~ /multipart\/form-data/) {
            my ($boundary) = ($ctype =~ /boundary=(\S+)$/);
            $boundary =~ s/^\"(\S+)\"$/$1/;
            my $clen = defined($p{CONTENT_LENGTH}) ? $p{CONTENT_LENGTH} : $ENV{CONTENT_LENGTH} || 0;
            @data = multipart_data($clen, $boundary, @_);
        }
        else {
            $error = 'Unknown Content-type: '.$ctype;
        }
    }
    else {
        $error = 'Unknown Request method: '.$method;
    }
    
    # Перекодируем список параметров согласно кодировкам
    if ($cssrc || $csdst) {
        @data = encode($cssrc, $csdst, @data);
    }
    elsif (!$csdst) {
        require Encode;
        Encode::_utf8_on($_) foreach @data;
    }
    
    # Выводим либо объект с параметрами, либо просто список параметров
    return $p{prepare} ?
        Clib::Web::Param::Prepare->new(@data) :
        @data;
}

sub multipart_data {
    my $clen = shift;
    my $boundary = shift;
    my %p = @_;
    
    # Наиболее сложный формат данных - multipart/form-data
    # Параметры разделены строкой $boundary, среди них могут встречаться файлы
    my @data = ();
    
    my $m1 = $boundary =~ s/^(-+)// ? length($1) : 0;
    my $m2 = $boundary =~ s/(-+)$// ? length($1) : 0;
    
    my $content = '';
    my $isbound = sub {
        my $isfirst = shift; # Самый первый boundary может начинаться не с перевода строки
        if (($content =~ /^(\015?\012)?(\-*)([^\s\-]+)(\-*)\015?\012/) &&
            ($isfirst || $1) &&
            (length($2) >= $m1) && ($3 eq $boundary) && (length($4) >= $m2)) {
            $content = $'; # Оставшиеся данные;
            $content =~ s/^\s+//;
            return 1;
        }
        return;
    };
    
    my $cread = sub {
        return 1 if ($clen <= 0) || (length($content) >= 1024);
        my $stdin = $p{STDIN} || \*STDIN;
        my $buf;
        my $len = read ($stdin, $buf, $clen > 1024 ? 1024 : $clen);
        if (!$len || ($len < 0)) {
            $error = 'STDIN read error: '.$!;
            return;
        }
        $content .= $buf;
        $clen -= $len;
        return 1;
    };
    
    $cread->() || return;
    if (!$isbound->(1)) { # Самый первый boundary, удаляем его и каждый новый цикл у нас должен начинаться с disposition
        $error = 'Multipart first boundary fail on: '.$content;
        return @data;
    }
    my $fhnd = $p{file};
    $fhnd = {} if ref($fhnd) ne 'HASH';
    while (($clen > 0) || ($content ne '')) {
        # Disposition
        if ($content !~ s/^[Cc]ontent-[Dd]isposition: ([^\015\012]+)\015?\012//) {
            $error = 'Multipart disposition fail on: '.$content;
            last;
        }
        my $disposition = $1;
        my ($name) = ($disposition =~ /name="([^"]+)"/);
        my ($file) = ($disposition =~ /filename="([^"]+)"/);
        
        my $fh = defined($file) ? fileopen($fhnd->{$name}, $name, $file) : undef;
        
        # Headers
        my @hdr = ();
        while ($content =~ s/^([^\s\:]+)\: ([^\015\012]+)\015?\012//) {
            push @hdr, $1 => $2;
        }
        
        # Пустая строка перед данными
        if ($content !~ s/^\015?\012//) {
            $error = 'Multipart headers end fail on: '.$content;
            last;
        }
        
        # читаем данные
        my $ok = 0;
        my $data = '';
        while ($cread->() && ($content ne '')) {
            if ($isbound->()) {
                $ok = 1;
                last;
            }
            # будем читать построчно, чтобы не пропустить boundary
            my $n = 0;
            if ($content =~ s/^([\015\012])//) {       # стираем все пробельные символы в начале по одному, чтобы не пропустить boundary
                if ($fh) {
                    print $fh $1;
                }
                elsif (!defined($file)) {
                    $data .= $1;
                }
                $content = $'; # Оставшиеся данные;
                $n++;
            }
            if ($content =~ s/^([^\015\012]+)//) {  #    данные строки до её окончания
                if ($fh) {
                    print $fh $1;
                }
                elsif (!defined($file)) {
                    $data .= $1;
                }
                $content = $'; # Оставшиеся данные;
                $n++;
            }
            if (!$n) {
                $error = 'Multipart data parse fail on: '.$content;
                return @data;
            }
        }
        if ($fh) {
            close $fh;
        }
        if (!$ok) {
            $error = 'Multipart last boundary fail on: '.$data;
            return @data;
        }
        if (defined $name) {
            if (defined $file) {
                push @data, url_decode($name) => url_decode($file);
            }
            else {
                push @data, url_decode($name) => $data;
            }
        }
    }
    
    return @data;
}

sub fileopen {
    my $hnd = shift;
            
    my $fh;
    if (ref($hnd) eq 'SCALAR') {
        open($fh, '>', $hnd) || return;
    }
    elsif (ref($hnd) eq 'SUB') {
        return $hnd->(@_);
    }
    elsif (defined($hnd) && !ref($hnd)) {
        open($fh, '>', $hnd) || return;
    }
            
    return $fh;
}


=head2 web_cookie(...)

Парсит COOKIE-данные.

В простом варианте возвращает хеш ключ-значение параметров запроса.

    use Clib::Web::Param;
    
    my %p = web_cookie();
    
    my $val1 = $p{field1};

Параметры вызова:

=over 4

=item *

Флаг C<prepare> - В этом случае C<web_cookie(...)> вернёт объект, который позволит
более гибко работать с полученными параметрами.

=back

=cut

sub cookie {
    my %p = @_;
    
    my $cook = defined($p{HTTP_COOKIE}) ? $p{HTTP_COOKIE} : $ENV{HTTP_COOKIE} || '';
    
    my @data = url_data($cook, ';\s+');
    
    return $p{prepare} ?
        Clib::Web::Param::Prepare->new(@data) :
        @data;
}



=head2 web_cookieset(key => 'val', ... доп параметры ...)

Запоминает глобально, какие cookie надо будет отправить в ответ на запрос.

Необязательные дополнительные параметры (хэш "ключ-значение"):

=over 4

=item *

C<domain> - домен, в котором должны действовать этот куки.

=item *

C<path> - относительный путь url, для которого будут действовать этот куки.

=item *

C<permanent> - флаг (значение: 1/0), делающий этот куки постоянным.
На самом деле выставляется C<expire=10-Feb-2099>

=item *

C<expires> - дата время, когда будет удалён куки. Формат: C<Wed, 10-Feb-2099 00:00:00 GMT>

=item *

C<delete> - флаг (значение: 1/0), означающий удаление куки с помощью выставления
C<expire=01 Jan 1970>

=back

=cut

my %cookie = ();
sub cookieset { 
    return if @_ < 2;
    my $key = shift;
    $cookie{$key} = { value => @_ };
}



=head2 web_cookiebuild()

Возвращает хеш из запомненных куки с помощью C<web_cookieset()> в формате HTTP-заголовков.

=cut

sub cookiebuild {
    my @head = ();
    foreach my $key (keys %cookie) {
        my $cookie = $cookie{$key};
        my $s = $key.'='.url_encode($cookie->{value});
        if ($cookie->{domain}) {
            $s .= '; domain='.url_encode($cookie->{domain});
        }
        if ($cookie->{path}) {
            $s .= '; path='.$cookie->{path};
        }
        if ($cookie->{permanent} || $cookie->{perm}) {
            $s .= '; expires=Wed, 10-Feb-2099 00:00:00 GMT';
        }
        elsif ($cookie->{expires}) {
            $s .= '; expires='.$cookie->{expires};
        }
        elsif ($cookie->{del} || $cookie->{delete}) {
            $s .= '; expires=Thu, 01 Jan 1970 00:00:00 GMT';
        }
        push @head, 'Set-Cookie' => $s;
    }
    
    %cookie = ();
    return @head;
}

=head1 Методы класса C<Clib::Web::Param::Prepare>

Объект этого класса будет возвращён функциями C<web_param(...)> или C<web_cookie(...)>,
если указать параметр C<prepare => 1>.

=cut

package Clib::Web::Param::Prepare;

sub new {
    my $class = shift;
    
    my $self = { orig => [@_], bykey => {}, keys => [] };
    
    my $bykey = $self->{bykey};
    my $keys = $self->{keys};
    while (@_) {
        my $key = shift;
        my $value = shift;
        push @{ $bykey->{$key} ||= [] }, $value;
        push @$keys, $key;
    }
    
    bless $self, $class;
    
    return $self;
}


=head2 exists($key)

Вернёт 1, если параметр с указанным именем существует

=cut

sub exists {
    my ($self, $key) = @_;
    
    return exists $self->{bykey}->{$key};
}


=head2 keys()

Вернёт массив всех ключей в том порядке, в котором они встретились. Повторно встреченные ключи
будут повторяться в возвращаемом списке.

=cut

sub keys { @{shift->{keys}} }


=head2 orig()

Вернёт хеш C<ключ-значение> всех ключей и их значений в первоначальном порядке.

=cut

sub orig { @{shift->{orig}} }


=head2 exp($key1, $key2...)

Вернёт хеш C<ключ-значение> всех переданных в аргументах параметров в первоначальном порядке.

Вызов метода без аргументов идентичен методу orig().

=cut

sub exp {
    my $self = shift;
    @_ || return @{ $self->{orig} };
    my %k = map { ($_ => 1) } @_;
    my @o = @{ $self->{orig} };
    my @r = ();
    while (@o) {
        my $k = shift @o;
        my $v = shift @o;
        if ($k{$k}) {
            push @r, $k => $v;
        }
    }
    return @r;
}


=head2 rebuild($key1 => 'val1')

Пересборка обратно в формат QUERY_STRING. Если в аргументах указан хеш, то все исходные параметры
с указанными именами будут пропущены и добавлены в конец этой строки с новыми значениями.

=cut

sub rebuild {
    my $self = shift;
    my %p = @_;
    
    my @p = ();
    my @orig = @{ $self->{orig} };
    while (@orig) {
        my $k = shift @orig;
        my $v = shift @orig;
        next if exists $p{$k};
        push @p, $k => $v;
    }
    
    return Clib::Web::Param::data2url(@p, @_);
}


=head2 raw($key)

Оригинальное значение параметра.

Если с именем C<$key> встречалось более одного параметра, то будет возвращено первое встретившееся значение.

=cut

sub raw {
    my ($self, $key) = @_;
    
    return ($self->{bykey}->{$key}||[])->[0];
}


=head2 int($key)

Значение параметра в числовом формате. Если значение начиналось с цифр, но содержит не только цифры,
оно будет преобразовано в число по правилам perl. Если значение параметра было не числом, будет возвращён ноль.

Возвращаемое значение всегда defined.

Если с именем C<$key> встречалось более одного параметра, то будет возвращено первое встретившееся значение.

=cut

sub int {
    my $val = raw(@_);
    
    return defined($val) && ($val =~ /^([+-]?\d+)/) ? $1*1 : 0;
}


=head2 uint($key)

Значение параметра в числовом формате. Отрицательное число станет нулём.

Если с именем C<$key> встречалось более одного параметра, то будет возвращено первое встретившееся значение.

=cut

sub uint {
    my $val = raw(@_);
    
    return defined($val) && ($val =~ /^\+?(\d+)/) ? $1*1 : 0;
}


=head2 float($key)

Значение параметра в дробном формате.

Возвращаемое значение всегда defined.

Если с именем C<$key> встречалось более одного параметра, то будет возвращено первое встретившееся значение.

=cut

sub float {
    my $val = raw(@_);
    
    return
        defined($val) && ($val =~ /^([+-]?\d+)([,.](\d+))?/) ?
            ($2 ? ($1*1).'.'.$3 : $1*1) :
            0;
}


=head2 ufloat($key)

Значение параметра в дробном формате. Отрицательное число станет нулём.

Если с именем C<$key> встречалось более одного параметра, то будет возвращено первое встретившееся значение.

=cut

sub ufloat {
    my $val = raw(@_);
    
    return
        defined($val) && ($val =~ /^(\+?\d+)([,.](\d+))?/) ?
            ($2 ? ($1*1).'.'.$3 : $1*1) :
            0;
}


=head2 code($key)

Значение, в котором будут отброшены любые символы кроме букв и цифр.

Возвращаемое значение всегда defined.

Если с именем C<$key> встречалось более одного параметра, то будет возвращено первое встретившееся значение.

=cut

sub code {
    my $val = raw(@_);
    
    $val = '' unless defined $val;
    $val =~ s/[^\w\d]+//g;
    
    return $val;
}


=head2 str($key)

Значение, в котором будут отброшены любые пробельные символы в начале и в конце строки.

Возвращаемое значение всегда defined.

Если с именем C<$key> встречалось более одного параметра, то будет возвращено первое встретившееся значение.

=cut

sub str {
    my $val = raw(@_);
    
    $val = '' unless defined $val;
    $val =~ s/^[\000-\040]+//;
    $val =~ s/[\000-\040]+$//;
    
    return $val;
}


=head2 bool($key)

Вернёт 1, если исходное значение было параметра: y, yes, on. Во всех остальных случаях вернёт 0.

Возвращаемое значение всегда defined.

Если с именем C<$key> встречалось более одного параметра, то будет возвращено первое встретившееся значение.

=cut

sub bool {
    my $val = raw(@_);
    
    return
        $val && 
        (($val eq 'on') || ($val =~ /^y(es)?$/i) || ($val eq '1')) ? 
            1 : 0;
}


=head2 all($key)

Вернёт все значения параметра C<$key>, встретившиеся в первоначальном порядке.

=cut

sub all {
    my ($self, $key) = @_;
    
    my $v = $self->{bykey}->{$key} || return;
    return @$v;
}


=head2 allXXX($key)

Все методы с префиксом all (например: allint($key)) возвращают значения в том же формате,
что их короткие варианты. Но в данном случае будут возвращены все значения указанного параметра,
встретившиеся в первоначальном порядке.

Эти методы всегда возвращают массив. Поэтому в скалярном контексте там будет всегда количество элементов,
а не значение.

=cut

sub allint {
    return
        map {
            defined($_) && /^([+-]?\d+)/ ? $1*1 : 0;
        }
        all(@_);
}

sub alluint {
    return
        map {
            defined($_) && /^\+?(\d+)/ ? $1*1 : 0;
        }
        all(@_);
}

sub allfloat {
    return
        map {
            defined($_) && /^([+-]?\d+)([,.](\d+))?/ ?
                ($2 ? ($1*1).'.'.$3 : $1*1) :
                0;
        }
        all(@_);
}

sub allufloat {
    return
        map {
            defined($_) && /^(\+?\d+)([,.](\d+))?/ ?
                ($2 ? ($1*1).'.'.$3 : $1*1) :
                0;
        }
        all(@_);
}

sub allcode {
    return
        map {
            my $val = defined($_) ? $_ : '';
            $val =~ s/[^\w\d]+//g;
            $val;
        }
        all(@_);
}

sub allstr {
    return
        map {
            my $val = defined($_) ? $_ : '';
            $val =~ s/^[\000-\040]+//;
            $val =~ s/[\000-\040]+$//;
            $val;
        }
        all(@_);
}

sub allbool {
    return
        map {
            $_ && 
            (($_ eq 'on') || ($_ =~ /^y(es)?$/i) || ($_ eq '1')) ? 
                1 : 0;
        }
        all(@_);
}



1;
