package Clib::Web::Controller;

use strict;
use warnings;

my @attr_valid;
my %attr_valid;
my @attr_all;
my $static;
my %loaded = ();


=pod

=encoding UTF-8

=head1 NAME

Clib::Web::Controller - HTTP-контроллер, позволяющий делать из структуры pm-модулей и функций в ник формировать красивые URL.

=head1 SYNOPSIS
    
    use Clib::Web::Controller;

    webctrl_local(
            'CMain',
            attr => [qw/Title ReturnDebug ReturnText/],
            eval => "
                use Clib::Const;
                use Clib::Log;
            
                *wparam = *WebMain::param;
            ",
        ) || die webctrl_error;


    package CMain::Load;
    
    sub _root :
            ParamUInt
            ReturnText
    {
        return 'OK';
    }
    
    sub form :
            ParamUInt
    {
        my $id = shift();
        return 'form';
    }

Указанный пример сформирует пути:

=over 4

=item *

C</load> - обработчик: функция CMain::Load::_root()

=item *
    
C</load/XXX/form> - обработчик: функция CMain::Load::form()

При вызове этой функции будет передан аргумент со значением XXX из URL.

Для данного URL XXX может состоять только из цифр.

=back

=head1 Принцип

Вся ветка модулей, начинающихся на C<CMain> (из примера) будет просканирована.
Все фукнции с аттрибутами станут обработчиками URL, которые формируются исходя из пути к этой функции.

Например, для пути к функции C<CMain::Load::_root()> действуют правила:

=over 4

=item *

Префикс, указанный как C<$srch_class> (в примере: CMain) пропускается.

=item *

Все C<::> будут заменены на C</>.

=item *

Имя C<_root> (м.б. именем модуля или функции) пропускается.

=item *

Стандартные атрибуты C<ParamXXX> дописываются в конце пути перед именем функции в порядке их указания.

=back

=head1 Методы

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
    
    foreach my $f (qw/error local extadd extdel bypath search do pref/) {
        *{"${callpkg}::webctrl_$f"} = sub {
            $static ||= new();
            
            my $sub = *{$f};
            
            return $sub->($static, @_);
        };
    }
}

=head2 new()

Возвращает экземпляр объекта. Аргументов вызова нет.

=cut

sub new {
    my $class = shift;
    
    my $self = { fast => {}, list => [], bypath => {} };
    
    if ($class) {
        bless $self, $class;
    }
    
    return $self;
}

=head2 error()

Возвращает ошибку, которая возникла при работе с этим объектом.

=cut

sub error {
    my $self = shift;
    
    if (@_) {
        my $error = shift;
        if (defined($error) && ($error ne '')) {
            $self->{error} = $error;
        }
        else {
            delete $self->{error};
        }
    }
    
    return $self->{error};
}

=head2 local($srch_class, ...)

Добавляет в данный объект локальную ветку модулей, название которых начинается на $srch_class

Доп параметры вызова:

=over 4

=item *

C<attr> - список особых допустимых аттрибутов функций-обработчиков.

=item *

C<eval> - perl-код, который будет выполнен для каждого найденного модуля.

Позволяет не дублировать один и тот же код во всех модулях контроллера.

=back

=cut

sub local {
    my ($self, $srch_class, %p) = @_;
    
    $self = $self->new() if !ref($self);
    
    require Module::Find;
    
    my @module = Module::Find::findallmod($srch_class);
    
    if (!@module) {
        $self->{error} = 'Can\'t find any modules for srch-class \''.$srch_class.'\'';
        return;
    }
    
    @attr_valid = (
        qw/Simple Name
            Param ParamRegexp ParamInt ParamUInt
            ParamCode ParamCodeInt ParamCodeUInt
            ParamWord
            ParamEnd/,
        @{ $p{attr}||[] }
    );
    %attr_valid = map { (lc($_) => 1) } @attr_valid;
    
    # Загружаем модуль с расширенной диспетчеризацией
    push @UNIVERSAL::ISA, 'Clib::Web::Controller::Base'
        unless grep { $_ eq 'Clib::Web::Controller::Base' } @UNIVERSAL::ISA;
    
    my $ok = 1;
    foreach my $pkg (@module) {
        next if $loaded{$pkg}; # Защита от повторной загрузки одного и того же модуля
        if (!pkgload($self, $pkg, $srch_class, $p{eval})) {
            $ok = 0;
            last;
        }
        $loaded{$pkg} = 1;
        # Повторная загрузка может происходить при повторном вызове local.
        # Например, при модульной системе, когда мы делаем use lib для каждого модуля
        # и рассчитываем там увидеть только файлы контроллера этого модуля (Module::Find::findallmod),
        # а туда ещё подмешиваюся файлы из базового модуля/проекта, use lib которого мы не отменяли
    }
    
    @UNIVERSAL::ISA = grep { $_ ne 'Clib::Web::Controller::Base' } @UNIVERSAL::ISA;
    
    @attr_valid = ();
    %attr_valid = ();
    
    $ok || return;
    
    return $self;
}

sub pkgload {
    my ($self, $pkg, $srch_class, $eval) = @_;
    
    @attr_all = ();
    
    $eval = $eval ? "package $pkg; $eval" : '';
    
    my $ok = eval "$eval\nrequire $pkg;";
    if (!$ok || $@) {
        $self->{error} = 'Cant\' load \''.$pkg.'\': '.($@||'-unknown-');
        return;
    }
    
    foreach my $disp (_attr2disp($srch_class)) {
        $disp->{local} = $srch_class;
        if ($disp->{regexp}) {
            push @{ $self->{list} }, $disp;
        }
        else {
            $self->{fast}->{ $disp->{path} } ||= $disp;
        }
        $self->{bypath}->{ $disp->{path} } ||= $disp;
    }
    
    @attr_all = ();
    
    return 1;
}

sub alllocal {
    my $self = shift;
    
    return
        map {{
            path => $_->{path},
            href => $_->{href},
            name => $_->{name},
            symbol => $_->{symbol},
            $_->{attr} ? (attr => $_->{attr}) : (),
            $_->{regexp} ? (regexp => $_->{regexp}) : (),
            defined($_->{param_count}) ? (param_count => $_->{param_count}) : (),
        }}
        grep { $_->{local} }
        (values(%{ $self->{fast} }), @{ $self->{list} });
}

sub extadd {
    my ($self, $module, $disp, $func) = @_;
    
    $self = $self->new() if !ref($self);
    
    return if
        !$module || !$disp || !$disp->{path} || !$disp->{href} || (ref($func) ne 'CODE');
    
    $disp = {
        ext  => $module,
        path => $disp->{path},
        href => $disp->{href},
        name => $disp->{name},
        $disp->{attr} ? (attr => $disp->{attr}) : (),
        $disp->{regexp} ? (regexp => $disp->{regexp}) : (),
        $disp->{symbol} ? (symbol => $disp->{symbol}) : (),
        defined($disp->{param_count}) ? (param_count => $disp->{param_count}) : (),
        func => $func,
    };
    
    if (!defined($disp->{name})) {
        ($disp->{name}) = reverse split(/\//, $disp->{path});
    }
    
    if ($disp->{regexp}) {
        push @{ $self->{list} }, $disp;
    }
    else {
        $self->{fast}->{ $disp->{path} } ||= $disp;
    }
    $self->{bypath}->{ $disp->{path} } ||= $disp;
    
    $self;
}

sub extdel {
    my ($self, $module, $path) = @_;
    
    my @del = ();
    if (defined $path) {
        my $disp = $self->{fast}->{$path};
        if ($disp && defined($disp->{ext}) && ($disp->{ext} eq $module)) {
            delete $self->{fast}->{$path};
            push @del, $disp;
        }
        
        my @list = ();
        foreach my $disp (@{ $self->{list} }) {
            if (defined($disp->{ext}) && ($disp->{ext} eq $module) && ($disp->{path} ne $path)) {
                push @del, $disp;
            }
            else {
                push @del, $disp;
            }
        }
        @{ $self->{list} } = @list;
    }
    else {
        @del =
            grep { defined($_->{ext}) && ($_->{ext} eq $module) }
            values %{ $self->{fast} };
        delete($self->{fast}->{$_->{path}}) foreach @del;
        
        my @list = ();
        foreach my $disp (@{ $self->{list} }) {
            if (defined($disp->{ext}) && ($disp->{ext} eq $module)) {
                push @del, $disp;
            }
            else {
                push @list, $disp;
            }
        }
        @{ $self->{list} } = @list;
    }
    
    delete($self->{bypath}->{$_->{path}}) foreach @del;
    
    return @del;
}

sub prefix {
    my $self = shift;
    
    if (@_) {
        my $prefix = shift;
        if (defined $prefix) {
            $prefix =~ s/^\/+//;
            #$prefix =~ s/\/+$//;
        }
        if (defined($prefix) && ($prefix ne '')) {
            $self->{prefix} = $prefix;
        }
        else {
            delete $self->{prefix};
        }
    }
    
    return $self->{prefix};
}

=head2 search($path)

Ищет нужный обработчик по запрашиваемому URL.

=cut

sub search {
    my ($self, $path) = @_;
    
    $path = '' unless defined $path;
    $path =~ s/^\/+//;
    
    if (defined(my $prefix = $self->{prefix})) {
        my $len = length $prefix;
        return if substr($path, 0, $len) ne $prefix;
        $path = substr($path, $len, length($path)-$len);
        $path =~ s/^\/+//;
    }
    
    my $disp = $self->{fast}->{$path};
    return $disp if $disp;
    
    foreach my $disp (@{ $self->{list} }) {
        if ($disp->{regexp} && (my @par = ($path =~ /$disp->{regexp}/))) {
            return wantarray ? ($disp, @par) : $disp;
        }
    }
    
    return;
}

=head2 bypath($path)

Если HTTP-контроллер использует только простые пути без доп. аргументов (нет тэгов ParamXXX),
то поиск через C<bypath> будет более быстрым, т.к. обращается сразу по ссылке и не перебирает
все ссылки по регулярным выражениям.

=cut

sub bypath {
    my ($self, $path) = @_;
    return $self->{bypath}->{$path};
}

=head2 pref($path, @arg)

Возвращает ссылку с собранными в неё значениями аргументов.

При вызове в $path все места, где должны быть аргументы вызова, должны быть пропущены.

Например, если у нас такой обработчик:

    package CMain::Load;
    
    sub form :
            ParamUInt
    {
        my $id = shift();
        return 'form';
    }

Мы можем вызвать:

    my $href = $ctrl->pref('load/form', 123);
    #
    #   $href будет содержать:
    #
    #       /load/123/form
    #

=cut

sub pref {
    my ($self, $path, @arg) = @_;
    
    my $disp = bypath($self, $path) || return;
    return @arg ? sprintf($disp->{href}, @arg) : $disp->{href};
}

=head2 do($disp, @param)

Вызывает найденный с помощью search() обработчик:

    my $url = '/load/123/form';
    
    my ($disp, @webp) = $ctrl->search($url);
    my @ret = $ctrl->do($disp, @webp);

В C<@ret> будет то, что вернула функция C<CMain::Load::form()>

=cut

sub do {
    my ($self, $disp, @param) = @_;
    
    $disp || return;
    
    my $func = $disp->{func} || return;
    
    if ($disp->{param_code}) {
        # Специальный обработчик параметра(ов)
        my $n = -1;
        foreach my $code (@{ $disp->{param_code} }) {
            $n++;
            next if ref($code) ne 'CODE';
            $param[$n] = $code->($param[$n], \@param);
        }
    }
    
    return $func->(@param);
}

sub _attr2disp {
    my $srch_class = shift;
    my $srch_class_len = length $srch_class;
    my %name = ();
    
    my @disp = ();
    
    foreach my $obj (@attr_all) {
        my $pkg = $obj->{pkg};
        
        my $ref2name = ($name{ $pkg } ||= { _ref2subname($pkg) });
        
        my $disp = { pkg => $pkg, name => $ref2name->{$obj->{ref}}, func => $obj->{ref} };
        if ($srch_class_len) {
            next if substr($pkg, 0, $srch_class_len) ne $srch_class;
            $pkg = substr $pkg, $srch_class_len, length($pkg) - $srch_class_len;
        }
        
        my @param = ();
        my @other = ();
        my $paramend = 0;
        foreach my $attr (@{ $obj->{attr} }) {
            if ($attr->{name} =~ /^Simple$/i) {
                next;
            }
            elsif ($attr->{name} =~ /^Name$/i) {
                if (my $arg = $attr->{arg}) {
                    $disp->{name_orig} = $disp->{name};
                    $disp->{name} = $arg->[0] || '_';
                }
            }
            elsif ($attr->{name} =~ /^(Param(Regexp|Int|UInt|Code|CodeU?Int|Word)?)$/i) {
                push @param, $attr;
            }
            elsif ($attr->{name} =~ /^ParamEnd$/i) {
                $paramend = 1;
            }
            else {
                push @other, [ $attr->{name}, @{ $attr->{arg}||[] } ];
            }
        }
        
        # Проверка и преобразование ключа элемента
        my @path =
            grep { ($_ ne '_') && ($_ ne '_root') }
            _keypath($pkg, $disp->{name});
        
        # Формируем элемент
        $disp->{path} = join('/', @path);
        $disp->{href} = $disp->{path};
        $disp->{symbol} = $disp->{pkg}.'::'.$disp->{name};
        $disp->{symbol_orig} = $disp->{pkg}.'::'.$disp->{name_orig} if $disp->{name_orig};
        
        # Если есть параметры, то формируем путь
        if (@param) {
            my @pattern = @path;
            foreach (@path) {
                s/([^\w\d\_])/\\$1/g;
            }
            my $func_name = !$paramend && (@path > 1) ? pop @path : '';
            my $func_patt = !$paramend && (@pattern > 1) ? pop @pattern : '';
            
            my $n = -1;
            foreach my $p (@param) {
                $n++;
                my $ind_code = 0;
                if (($p->{name} =~ /^ParamRegexp$/i) && $p->{arg} && $p->{arg}->[0]) {
                    push @path, "($p->{arg}->[0])";
                    push @pattern, '%s';
                }
                elsif ($p->{name} =~ /^ParamInt$/i) {
                    push @path, '(-?\d+)';
                    push @pattern, '%d';
                }
                elsif ($p->{name} =~ /^ParamUInt$/i) {
                    push @path, '(\d+)';
                    push @pattern, '%d';
                }
                elsif ($p->{name} =~ /^ParamCode$/i) {
                    push @path, '([^\/]+)';
                    push @pattern, '%s';
                    ($disp->{param_code}||=[])->[$n] = $p->{arg}->[0] if ref($p->{arg}->[0]) eq 'CODE';
                }
                elsif ($p->{name} =~ /^ParamCodeU?Int$/i) {
                    push @path, '(\d+)';
                    push @pattern, '%d';
                    ($disp->{param_code}||=[])->[$n] = $p->{arg}->[0] if ref($p->{arg}->[0]) eq 'CODE';
                }
                elsif ($p->{name} =~ /^Param$/i) {
                    push @path, '([^\/]*)'; # Тут м.б. пустая строка, т.е. вот так: "...//..."
                    push @pattern, '%s';
                }
                elsif (($p->{name} =~ /^Word$/i) && $p->{arg} && $p->{arg}->[0] && ($p->{arg}->[0] =~ /^[a-zA-Z0-9\_\-]+$/)) {
                    push @path, "$p->{arg}->[0]";
                    push @pattern, $p->{arg}->[0];
                    $n --;
                }
                else {
                    push @path, '([^\/]+)';
                    push @pattern, '%s';
                }
            }
            
            if ($func_name) {
                push @path, $func_name;
                push @pattern, $func_patt;
            }
            
            
            $disp->{regexp} = '^'.join('\/', @path).'$';
            $disp->{href} = join '/', @pattern;
            $disp->{param_count} = @param;
        }
        
        $disp->{attr} = [@other] if @other;
        
        push @disp, $disp;
    }
    
    return @disp;
}

sub _ref2subname {
    my $pkg = shift;
    no strict 'refs';
    my %ref = %{*{"$pkg\::"}};
    my %name = ();
    foreach my $key (keys %ref) {
        $key || next;
        my $val = $ref{$key};
        defined($val) || next;
        local(*ENTRY) = $val;
        my $ref = *ENTRY{CODE} || next;
        $name{ $ref } = $key;
    }

    return %name;
}

sub _keypath {
    my @list= @_;
    
    my @path = ();
    foreach (@list) {
        $_ = lc $_;
        my @path1 = grep { $_ } split /(?: +|\:\:|\\|\/)/;
        push @path, @path1;
    }
    
    return wantarray ? @path : join('/', @path);
}

package Clib::Web::Controller::Base;

use attributes;


sub MODIFY_CODE_ATTRIBUTES{
    my ($pkg, $ref, @attr1) = @_;
 
    my @unknown;
    my $attr;
    foreach (@attr1){
        my $name = $_;
        my $arg = undef;
        if ($name =~ /^([^\(]+)(\(.*\))$/) {
            $name = $1;
            $arg = eval "package $pkg; [$2];";
        }
        if (!$attr_valid{lc $name} || (ref($ref) ne 'CODE')) {
            push @unknown, $_;
            next;
        }
        
        if (!$attr && (ref($ref) eq 'CODE')) {
            $attr = { pkg => $pkg, ref => $ref, attr => [] };
            push @attr_all, $attr;
        }
        
        push @{ $attr->{attr} }, { name => $name, arg => $arg };
    }
    return @unknown;
}

1;

__END__

=head1 Статичные функции

Модуль импортирует несколько статичных функций для быстрого поиска модулей, если не требуется несколько
веток

Все они начинаются с префикса C<webctrl_>. Например:

    webctrl_local($dir, ...);

Вызов этих функций работает с одним и тем же объектом, вызванным глобально.

=head1 Стандартные аттрибуты функций контроллера

=head2 Simple

Обозначает функцию-обработчик, которому не нужны никакие специфичные атрибуты.

=head2 Name

Переопределяет имя функции

=head2 Param

Любой аргумент. В любом случае у аргумента, встраимого в URL, всегда есть минимальные правила:
отсутствие пробелов, спецсимволов и всего, что недопустимо использовать в основной части URL

=head2 ParamRegexp

Аргумент, соответствующий регулярному выражению.

=head2 ParamInt

Аргумент - любое число

=head2 ParamUInt

Аргумент - любое положительное число

=head2 ParamCode

Аргумент, который будет обработан функцией.

    package CMain::Load;
    
    sub byId {
        my $id = shift();
        return find_rec_by_id($id);
    }
    
    sub form :
            ParamCode(\&byId)
    {
        my $rec = shift();
        return 'form';
    }

Тут в form() будет передан уже не C<$id>, а C<$rec>, полученная в C<byId()>.

=head2 ParamCodeInt

Аргумент - любое число, обработанное функцией.

=head2 ParamCodeUInt

Аргумент - любое положительное число, обработанное функцией.

=head2 ParamWord

Аргумент - любое слово. Допустимые символы: a-z, A-Z, 0-9, _ и -.

=head2 ParamEnd

Сообщает, чтобы в URL аргументы все шли в самом конце, после имени функции.

=cut
