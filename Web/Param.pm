package Clib::Web::Param;

use strict;
use warnings;

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
        *{"${callpkg}::web_$f"} = sub { return $sub->(); };
        *{"${callpkg}::web_e$f"} = sub { return $sub->(prepare => 1); };
    }
}

sub url_data {
    my $delimiter = $_[1] || '&';
    
    return
        map {
            map { url_decode($_) }
            split (/=/, $_, 2)
        }
        split(/$delimiter/, $_[0]);
}

sub data2url {
    my @s = ();
    
    while (@_) {
        my $k = url_encode(shift());
        my $v = url_encode(shift());
        push @s, $k . '=' . $v;
    }
    
    return join('&', @s);
}

sub url_encode
{
    my $string = shift;
    
    Encode::_utf8_off($string);
    $string =~ s/([^-.\w ])/sprintf('%%%02X', ord $1)/ge;
    $string =~ tr/ /+/;

    return $string;
}

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

my $error;
sub err {
    return $error;
}

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

sub cookie {
    my %p = @_;
    
    my $cook = defined($p{HTTP_COOKIE}) ? $p{HTTP_COOKIE} : $ENV{HTTP_COOKIE} || '';
    
    my @data = url_data($cook, ';\s+');
    
    return $p{prepare} ?
        Clib::Web::Param::Prepare->new(@data) :
        @data;
}


my %cookie = ();
sub cookieset { 
    return if @_ < 2;
    my $key = shift;
    $cookie{$key} = { value => @_ };
}
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

sub exists {
    my ($self, $key) = @_;
    
    return exists $self->{bykey}->{$key};
}

sub keys { @{shift->{keys}} }
sub orig { @{shift->{orig}} }

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

sub raw {
    my ($self, $key) = @_;
    
    return ($self->{bykey}->{$key}||[])->[0];
}

sub int {
    my $val = raw(@_);
    
    return defined($val) && ($val =~ /^([+-]?\d+)/) ? $1*1 : 0;
}

sub uint {
    my $val = raw(@_);
    
    return defined($val) && ($val =~ /^\+?(\d+)/) ? $1*1 : 0;
}

sub float {
    my $val = raw(@_);
    
    return
        defined($val) && ($val =~ /^([+-]?\d+)([,.](\d+))?/) ?
            ($2 ? ($1*1).'.'.$3 : $1*1) :
            0;
}

sub ufloat {
    my $val = raw(@_);
    
    return
        defined($val) && ($val =~ /^(\+?\d+)([,.](\d+))?/) ?
            ($2 ? ($1*1).'.'.$3 : $1*1) :
            0;
}

sub code {
    my $val = raw(@_);
    
    $val = '' unless defined $val;
    $val =~ s/[^\w\d]+//g;
    
    return $val;
}

sub str {
    my $val = raw(@_);
    
    $val = '' unless defined $val;
    $val =~ s/^[\000-\040]+//;
    $val =~ s/[\000-\040]+$//;
    
    return $val;
}

sub bool {
    my $val = raw(@_);
    
    return
        $val && 
        (($val eq 'on') || ($val =~ /^y(es)?$/i) || ($val eq '1')) ? 
            1 : 0;
}


sub all {
    my ($self, $key) = @_;
    
    my $v = $self->{bykey}->{$key} || return;
    return @$v;
}

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
