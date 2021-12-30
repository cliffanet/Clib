package Clib::BinProto;

use Clib::strict;

use POSIX 'round';


=pod

=encoding UTF-8

=head1 NAME

Clib::BinProto - Класс для шаблонного конвертирования данных в бинарный формат и обратно.

=head1 SYNOPSIS
    
    use Clib::BinProto;
    
    my $proto = Clib::BinProto->new(
        '%', # Заголовок пакета
        # шаблоны:
        { s => 0x01, code => 'hello', pk => 'Na32', key => 'authid,login' },
        { s => 0x02, code => 'bye',   pk => '',     key => '' },
    );
    
    my $bin =
        $proto->pack(
            hello   => { authid => 100, login => 'test' },
            bye     => {}
        );
    
    my $datalist = $proto->unpack( $bin );
    
    # содержимое $data:
    #   [
    #       { code => 'hello', authid => 100, login => 'test' }
    #       { code => 'bye' }
    #   ]

=head1 Коды форматирования

=over 4

=item *

C<C> - 1-байтовое целое

=item *

C<n> - 2-байтовое целое

=item *

C<N> - 4-байтовое целое

=item *

C<c> - 1-байтовое знаковое

=item *

C<i> - 2-байтовое знаковое

=item *

C<I> - 4-байтовое знаковое

=item *

C<v> - IP v4 адрес

=item *

C<T> - DateTime

=item *

C<t> - DateTime + в конце 1/100 секунды

=item *

C<f> - %0.2float

=item *

C<D> - double (64bit)

=item *

C<x> - hex16

=item *

C<X> - hex32

=item *

C<H> - hex64

=item *

C<a> - символ (строка в 1 байт)

=item *

C<aDD> - строка фиксированной длины, ограниченная DD символами

=item *

C<пробел> - один зарезервированный байт (без привязки к ключу)

=item *

C<S> - динамическая строка, где длина строки - 2 байта

=item *

C<s> - динамическая строка, где длина строки - 1 байт

=back

=head1 Структура бинарного пакета

Для каждой команды/шаблона:

    (заголовок)[1 байт] (команда/шаблон)[1 байт] (длина данных)[2 байта] (данные)

=over 4

=item *

Заголовок [1 байт] - Любой символ, указывается самым первым аргументов в методах new/init.
Этот символ одинаковый для всех шаблонах для данного объекта-протокола. Участвует в валидации
валидности протокола при распаковке.

=item *

Команда/шаблон [1 байт] - при инициализации шаблона указывается в параметре "s" - однобайтовое целое число.

=item *

Длина данных [2 байта] - длина бинарных данных (не всего пакета, а только данных)
в "network" (big-endian) формате.

=item *

Данные - бинарная последовательность, упакованная согласно формату в параметре "pk" шаблона.

=back

=cut

=head1 Методы

=cut

=head2 new($header, шаблон1, ... шаблон-N)

Создание объекта с описанием протокола.

Первый аргумент - это односимвольный заголовок. Это может быть любым символом и даже непечатаемым байтом.
С этого байта будет начинаться каждый пакет.

Под пакетом подразумевается одна команда, или некая одномерная структура данных, упакованная по определённому шаблону.

Все последующие аргументы - это перечисление шаблонов списком хешей. Каждый шаблон - это один хеш: 

    { параметры }

Параметры шаблона:

=over 4

=item *

C<code> - имя шаблона, использыется для удобно-читаемого указания в коде.

=item *

C<s> - код шаблона/команды, однобайтовое целое число - именно этот байт будет вторым в пакете.

=item *

C<pk> [необязательный] - шаблон заполнения пакета данными, синтаксис похож на формат-аргумент команды pack в perl.

=item *

C<key> [необязательный] - строка, где через запятую перечислены имена полей, которые упакованы по формату C<pk>.

=back

По сути: C<code> является символьным представлением бинарного кода C<s>,
а C<key> - это имена полей, которые упаковываются в той же последовательности по формату C<pk>.

Количество полей в C<key> должно соответствовать числу бинарный полей в C<pk>, иначе будет ошибка инициализации.

=cut

sub new {
    my $class = shift() || return;
    
    my $self = {
    };
    
    bless $self, $class;
    
    $self->init(@_);
    
    return $self;
}

=head2 error()

Возвращает текст ошибки в случае неудачного выполнения команд:
инициализации шаблонов C<new()>/C<init()>/C<add()>, упаковки C<pack()> или распаковки C<unpack()>.

В списковом контексте возвращает все ошибки, возникшие за время выполнения ^^^вышеуказанных функций.

В скалярном контексте влзвращает только последнюю ошибку.

=cut

sub error {
    my $self = shift;
    
    if (@_) {
        my $s = shift;
        $s = sprintf($s, @_) if @_;
        push @{ $self->{error}||=[] }, $s;
    }
    
    my $err = $self->{error}||[];
    
    return
        wantarray ?
            @$err :
        @$err ?
            $err->[scalar(@$err)-1] :
            ();
}

=head2 errclear()

Очищает список ошибок, обнаруженных ранее. Однако, при выполнении функций:
инициализации шаблонов C<new()>/C<init()>/C<add()>, упаковки C<pack()> или распаковки C<unpack()> -
этот метод вызывается автоматически и так, поэтому, как правило, дополнительный вызов не требуется.

=cut

sub errclear {
    my $self = shift;
    
    $self->{error} = [];
}

=head2 init(шаблон1, ... шаблон-N)

Инициализация шаблонов. Выполняет полный сброс текущих шаблонов и добавление новых.
Параметры вызова соответствуют вызову метода C<new()>, но без первого аргумента C<$header>.

=cut

sub init {
    my $self = shift;
    
    $self->{hdr} = shift() || return;
    
    $self->errclear();
    delete $self->{pack};
    delete $self->{unpack};
    delete $self->{code2s};
    
    $self->add(%$_) foreach @_;
    
    return @{ $self->{error}||[] } ? 0 : 1;
}

=head2 add(параметры-шаблона)

Добавление одного шаблона. Сброса текущих шаблонов не происходит.

При этом, заворачивать параметры в ссылку на хеш не требуется:

    $proto->add(
        s       => 0x01,
        code    => 'hello',
        pk      => 'Na32',
        key     => 'authid,login'
    );

=cut

sub add {
    my $self = shift;
    my %p = @_;
    
    $p{pk} ||= '';
    $p{key} ||= '';
    # элемент протокола (одномерных хэш ключ-значение)
    my @pk = split //, $p{pk};        # коды упаковки ключа элемента
    my @key = split /,/, $p{key};     # ключи элемента для упаковки
    
    # Для каждого ключа элемента получим набор функций для упаковки и набор функций для распаковки
    my $i = 0;
    my @pack = ();
    my @unpack = ();
    while (@pk) {
        $i ++;
        my $pk = shift @pk;
        my $key;
        if ($pk ne ' ') {
            $key = shift @key;
            if (!$key) {
                $self->error('[code=%s, key=%d] unknown key of element', $p{code}, $i);
            }
        }
        
        if (($pk eq 'C') || ($pk eq 'c')) {
            push @pack, sub {
                return
                    1,
                    CORE::pack($pk, defined($_[0]->{$key}) ? $_[0]->{$key} : 0);
            };
            push @unpack, sub {
                my $v = CORE::unpack($pk, $_[0]);
                return
                    1,
                    defined($v) ? ($key => $v) : ();
            };
        }
        
        elsif ($pk eq 'n') {
            push @pack, sub {
                return
                    2,
                    CORE::pack('n', defined($_[0]->{$key}) ? $_[0]->{$key} : 0);
            };
            push @unpack, sub {
                my ($v) = CORE::unpack('n', $_[0]);
                return
                    2,
                    defined($v) ? ($key => $v) : ();
            };
        }
        
        elsif ($pk eq 'N') {
            push @pack, sub {
                return
                    4,
                    CORE::pack('N', defined($_[0]->{$key}) ? $_[0]->{$key} : 0);
            };
            push @unpack, sub {
                my ($v) = CORE::unpack('N', $_[0]);
                return
                    4,
                    defined($v) ? ($key => $v) : ();
            };
        }
        
        elsif ($pk eq 'i') {
            push @pack, sub {
                return
                    2,
                    CORE::pack('n', defined($_[0]->{$key}) ? $_[0]->{$key} : 0);
            };
            push @unpack, sub {
                my ($v) = CORE::unpack('n', $_[0]);
                $v -= 0x10000 if defined($v) && ($v > 0x7fff);
                return
                    2,
                    defined($v) ? ($key => $v) : ();
            };
        }
        
        elsif ($pk eq 'I') {
            push @pack, sub {
                return
                    4,
                    CORE::pack('N', defined($_[0]->{$key}) ? $_[0]->{$key} : 0);
            };
            push @unpack, sub {
                my ($v) = CORE::unpack('N', $_[0]);
                if (defined($v) && ($v > 0x7fffffff)) {
                    $v -= 0xffffffff;
                    $v--;
                }
                return
                    4,
                    defined($v) ? ($key => $v) : ();
            };
        }
        
        elsif ($pk eq 'v') {
            push @pack, sub {
                return
                    4,
                    CORE::pack('C4', defined($_[0]->{$key}) ? split(/\./, $_[0]->{$key}) : (0,0,0,0));
            };
            push @unpack, sub {
                my @ip = CORE::unpack('C4', $_[0]);
                return
                    4,
                    (@ip == 4) && defined($ip[3]) ? ($key => join('.',@ip)) : ();
            };
        }
        
        elsif ($pk eq 'T') {
            push @pack, sub {
                my $dt = $_[0]->{$key};
                return
                    8,
                    CORE::pack('nCCCCCC',
                        $dt && ($dt =~ /^(\d{2,4})-(\d{1,2})-(\d{1,2}) (\d{1,2})\:(\d{1,2})\:(\d{1,2})$/) ?
                            (($1 < 100 ? $1+2000 : int($1)), int($2), int($3),  int($4), int($5), int($6),  0) :
                            (0,0,0, 0,0,0, 0)
                    );
            };
            push @unpack, sub {
                my @dt = CORE::unpack('nCCCCCC', $_[0]);
                return 
                    8,
                    (@dt == 7) && defined($dt[6]) ?
                        ($key => sprintf("%04d-%02d-%02d %d:%02d:%02d", @dt[0..5])) :
                        ();
            };
        }
        
        elsif ($pk eq 't') {
            push @pack, sub {
                my $dt = $_[0]->{$key};
                return
                    8,
                    CORE::pack('nCCCCCC',
                        $dt && ($dt =~ /^(\d{2,4})-(\d{1,2})-(\d{1,2}) (\d{1,2})\:(\d{1,2})\:(\d{1,2})(?:\.(\d\d))?$/) ?
                            (($1 < 100 ? $1+2000 : int($1)), int($2), int($3),  int($4), int($5), int($6), int($7||0)) :
                            (0,0,0, 0,0,0, 0)
                    );
            };
            push @unpack, sub {
                my @dt = CORE::unpack('nCCCCCC', $_[0]);
                return 
                    8,
                    (@dt == 7) && defined($dt[6]) ?
                        ($key => sprintf("%04d-%02d-%02d %d:%02d:%02d.%02d", @dt)) :
                        ();
            };
        }
        
        elsif ($pk eq 'f') {
            push @pack, sub {
                return
                    2,
                    CORE::pack('n', defined($_[0]->{$key}) ? POSIX::round($_[0]->{$key} * 100) : 0);
            };
            push @unpack, sub {
                my ($v) = CORE::unpack('n', $_[0]);
                $v -= 0x10000 if defined($v) && ($v > 0x7fff);
                return
                    2,
                    defined($v) ? ($key => sprintf('%0.2f', $v/100)) : ();
            };
        }
        
        elsif ($pk eq 'D') {
            push @pack, sub {
                my $v = defined($_[0]->{$key}) ? $_[0]->{$key} : 0;
                my $i = int $v;
                my $d = abs($v - $i);
                return
                    8,
                    CORE::pack('NN', $i, int($d * 0xffffffff));
            };
            push @unpack, sub {
                my ($i, $d) = CORE::unpack('NN', $_[0]);
                return 8 if !defined($i) || !defined($d);
                if ($i > 0x7fffffff) {
                    $i -= 0xffffffff;
                    $i--;
                }
                $d *= -1 if $i < 0;
                return
                    8,
                    $key => $i+($d/0xffffffff);
            };
        }
        
        elsif ($pk eq 'x') {
            push @pack, sub {
                return
                    2,
                    CORE::pack('n', defined($_[0]->{$key}) ? hex($_[0]->{$key}) : 0);
            };
            push @unpack, sub {
                my ($v) = CORE::unpack('n', $_[0]);
                return
                    2,
                    defined($v) ? ($key => sprintf('%04x', $v)) : ();
            };
        }
        
        elsif ($pk eq 'X') {
            push @pack, sub {
                return
                    4,
                    CORE::pack('N', defined($_[0]->{$key}) ? hex($_[0]->{$key}) : 0);
            };
            push @unpack, sub {
                my ($v) = CORE::unpack('N', $_[0]);
                return
                    4,
                    defined($v) ? ($key => sprintf('%08x', $v)) : ();
            };
        }
        
        elsif ($pk eq 'H') {
            push @pack, sub {
                my @h = ();
                if (defined $_[0]->{$key}) {
                    my $hex64 = $_[0]->{$key};
                
                    my $l = 0;
                    if ($hex64 =~ s/([0-9a-fA-F]{1,8})$//) {
                        $l = hex $1;
                    }
                    $hex64 = 0 if $hex64 eq '';
                    @h = (hex($hex64), $l);
                }
                else {
                    @h = (0,0);
                }
                
                return
                    8,
                    CORE::pack('NN', @h);
            };
            push @unpack, sub {
                my @h = CORE::unpack('NN', $_[0]);
                return
                    8,
                    (@h == 2) && defined($h[1]) ? ($key => sprintf('%08x%08x', @h)) : ();
            };
        }
        
        elsif ($pk eq ' ') {
            my $len = 1;
            while (@pk && ($pk[0] eq ' ')) {
                shift @pk;
                $len++;
            }
            push @pack, sub {
                return
                    $len,
                    CORE::pack('C' x $len, map { 0 } 1 .. $len);
            };
            push @unpack, sub { return $len; };
        }
        
        elsif ($pk eq 'a') {
            my @l = ();
            push(@l, shift(@pk)) while @pk && ($pk[0] =~ /^\d$/);
            my $l = @l ? join('', @l) : 1;
            
            # Какой-то непонятный глюк с a/Z параметрами
            # Если использовать aXX, то на тесте работает всё нормально,
            # а в боевом сетевом трафике почему-то не удаляются терминирующие нули при распаковке
            # С параметром Z такой проблемы нет, упаковка/распаковка - нормально,
            # Но параметр Z не умеет работать с одиночными символами
            my $pstr = $l > 1 ? 'Z'.$l : 'a';
            push @pack, sub {
                my $str = defined($_[0]->{$key}) ? $_[0]->{$key} : '';
                if (utf8::is_utf8($str)) {
                    utf8::downgrade($str);
                }
                return $l, CORE::pack($pstr, $str);
            };
            push @unpack, sub {
                my ($str) = CORE::unpack($pstr, $_[0]);
                $str = '' if defined($str) && ($l == 1) && ($str eq "\000");
                return $l, defined($str) ? ($key => $str) : ();
            };
        }
        
        elsif ($pk eq 's') {
            push @pack, sub {
                my $str = defined($_[0]->{$key}) ? $_[0]->{$key} : '';
                if (utf8::is_utf8($str)) {
                    utf8::downgrade($str);
                }
                my $l = length($str);
                if ($l > 255) {
                    $str = substr($str, 0, 255);
                    $l = 255;
                }
                
                return $l+1, CORE::pack('C', $l).$str;
            };
            push @unpack, sub {
                my ($l) = CORE::unpack('C', $_[0]);
                return (1) if !defined($l);
                return $l+1, $key => substr($_[0], 1, $l);
            };
        }
        
        elsif ($pk eq 'S') {
            push @pack, sub {
                my $str = defined($_[0]->{$key}) ? $_[0]->{$key} : '';
                if (utf8::is_utf8($str)) {
                    utf8::downgrade($str);
                }
                my $l = length($str);
                if ($l > 0xffff) {
                    $str = substr($str, 0, 0xffff);
                    $l = 0xffff;
                }
                
                return $l+2, CORE::pack('n', $l).$str;
            };
            push @unpack, sub {
                my ($l) = CORE::unpack('n', $_[0]);
                return (2) if !defined($l);
                return $l+2, $key => substr($_[0], 2, $l);
            };
        }
        
        else {
            $self->error('[code=%s, key=%d/%s] unknown pack code=%s', $p{code}, $i, $key, $pk);
        }
    }
    
    if (@key) {
        $self->error('[code=%s] keys without pack-code: %s', $p{code}, join(',', @key));
    }
    
    my $s = int $p{s};
    
    # Тепер формируем общие функции - упаковки и распаковки
    ($self->{pack}||={})->{ $p{code} } = sub {
        my $d = shift();
        my ($len, $data) = (0, '');
        foreach my $p (@pack) {
            my ($l, $s) = $p->($d);
            $len += $l;
            $data .= $s;
        }
            
        return CORE::pack('A1Cn', $self->{hdr}, $s, $len) . $data;
    };
    ($self->{unpack}||={})->{ $s } = sub {
        my $data = shift;
        my $len = shift;
        my @data = ();
        foreach my $p (@unpack) {
            my ($l, @d) = $p->($data);
            $len -= $l;
            $data .= $s;
            push @data, @d;
            $data = substr($data, $l, $len);
            last if $data eq '';
        }
        return @data, code => $p{code};
    };
    
    ($self->{code2s}||={})->{ $p{code} } = $p{s};
    
    1;
}

=head2 del($code)

Удаление шаблона с именем C<$code>.

Возвращает true, если пакет был в списке шаблонов объекта,
и undef - если шаблона с таким именем не существовало.

=cut

sub del {
    my $self = shift;
    my $code = shift() || return;
    
    my ($code2s, $pack, $unpack) = ($self->{code2s}||{}, $self->{pack}||{}, $self->{unpack}||{});
    exists($code2s->{ $code }) || return;
    
    my $s = delete $code2s->{ $code };
    delete $pack->{ $code };
    delete $unpack->{ $s };
    
    1;
}

=head2 pack(данные)

Упаковка данных по шаблону.

Данные могут быть представлены либо отдельным указанием имени шаблона и хешем данных:

    $proto->pack(
        имя_шаблона => { данные }
    );

либо хешем, внутри которого указано имя шаблона в поле C<code>:

    $proto->pack(
        { code => 'имя_шаблона', данные }
    );

За один вызов метода можно указать неограниченное количество пакетов с данными, все они будут
соединены в одну бинарную строку.

Длина бинарного пакета всегда соответствует тому, что указано в параметре C<pk> шаблона, по которому
упаковывается этот пакет. А в исходных данных, подставляемых для упаковки, должны присутствовать все
поля, указанные в C<key> шаблона.

=cut

sub pack {
    my $self = shift;
    $self->errclear();
    
    my $proto = $self->{pack} || {};
    
    my $data = '';
    my $n = 0;
    while (@_) {
        $n++;
        # Общая проверка входных данных
        my $code = shift;
        my $d = {};
        if (ref($code) eq 'HASH') {
            $d = $code;
            $code = $d->{code};
            if (!$code) {
                $self->error('pack[item#%d]: code undefined in hash-struc', $n);
                return;
            }
        }
        elsif (!ref($code)) {
            if (!$code) {
                $self->error('pack[item#%d]: code undefined', $n);
                return;
            }
            $d = shift() if @_;
            if (ref($d) ne 'HASH') {
                $self->error('pack[item#%d code%%%s]: not hash-struct', $n, $code);
                return;
            }
        }
        else {
            $self->error('pack[item#%d]: unknown data-type', $n);
            return;
        }
        
        # По какому элементу будем кодить
        my $pk = $proto->{$code};
        if (!$pk) {
            $self->error('pack[item#%d code%%%s]: element with unknown code', $n, $code);
            return;
        }
        
        $data .= $pk->($d);
    }
    
    return $data;
}

=head2 unpack($binstr)

Распаковка данных из бинарного потока.

В случае успеха распаковки возвращает ссылку на список хешей с распакованными данными:

    [
        { code => 'hello', authid => 100, login => 'test' }
        { code => 'bye' }
    ]

В случае ошибки распаковки возвращает C<undef>.

Т.к. в бинарном пакете указана фактическая длина данных, то пакет не будет распаковываться,
пока в исходной строке не будет передана вся ожидаемая длина.

Если пакет полностью присутствует, то он будет вырезан из исходной строки C<$binstr>.
Это удобно для обработки входящего потока данных.

Фактическая длина данных в пакете может оказаться длиннее или короче того, что указано
в C<pk> шаблона. Это никак не повлияет на целостность потока распаковываемых данных, т.к.
длина бинарного пакета будет определена исходя именно из длины, указанной в самом пакете,
а не из C<pk> шаблона. При этом, бинарный код, который окажется длинее указанного в C<pk> шаблона,
будет проигнорирован. А если бинарный код окажется короче ожидаемого, то поля, в недостающем участке
будут отсутствовать в возвращаемом хеше с данными для этого пакета.

=cut

sub unpack {
    my $self = shift;
    $self->errclear();
    
    my $proto = $self->{unpack} || {};
    my $hdr = $self->{hdr};
    
    if (!defined($hdr) || (length($hdr) != 1)) {
        $self->error('unpack: Call with wrong header: %s', defined($hdr) ? $hdr : '-undef-');
        return;
    }
    
    if (utf8::is_utf8($_[0])) {
        utf8::downgrade($_[0]);
    }
    
    my $len = length($_[0]) || return [];
    my $n = 0;
    my $ret = [];
    while ($len >= 4) {
        my ($hdr1,$s,$l) = unpack 'A1Cn', substr($_[0], 0, 4);
        
        # Общая проверка протокола по заголовку
        if ($hdr1 ne $hdr) {
            $self->error('unpack[item#%d]: element with unknown proto (hdr: %s, mustbe: %s)', $n, $hdr1, $hdr);
            return;
        }
        
        # По какому протоколу будем распаковывать
        my $upk = $proto->{$s};
        if (!$upk) {
            $self->error('ppack[item#%d]: element with unknown code (s: 0x%02x)', $n, $s);
            return;
        }
        
        return $ret if $len < (4+$l);
        
        push @$ret, { $upk->(substr($_[0], 4, $l), $l) };
        return if $self->error();
        
        $len -= 4+$l;
        $_[0] = substr $_[0], 4+$l, $len;
    }
    
    return $ret;
}

1;
