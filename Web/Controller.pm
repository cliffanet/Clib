package Clib::Web::Controller;

use strict;
use warnings;

my @attr_valid;
my %attr_valid;
my @attr_all;
my $static;
my %loaded = ();

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

sub new {
    my $class = shift;
    
    my $self = { fast => {}, list => [], bypath => {} };
    
    if ($class) {
        bless $self, $class;
    }
    
    return $self;
}

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

sub bypath {
    my ($self, $path) = @_;
    return $self->{bypath}->{$path};
}

sub pref {
    my ($self, $path, @arg) = @_;
    
    my $disp = bypath($self, $path) || return;
    return @arg ? sprintf($disp->{href}, @arg) : $disp->{href};
}

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

=pod
# code for this inspired by Devel::Symdump
sub _find_name_of_sub_in_pkg{
    my ($ref, $pkg) = @_;
    no strict 'refs';
    #return *{$ref}{NAME} if ref $ref eq 'GLOB';
    while (my ($key,$val) = each(%{*{"$pkg\::"}})) {
            local(*ENTRY) = $val;
            if (defined $val && defined *ENTRY{CODE}) {
                next unless *ENTRY{CODE} eq $ref;
                # rewind "each"
                my $a = scalar keys %{*{"$pkg\::"}};
                return $key;
            }
        }

    return undef;
}

sub _get_attr {
    my @attr1 = ();
    my %attr1 = ();
    
    foreach my $attr (@attr) {
        my $attr1 = {
            ref => $attr->{ref},
            pkg => $attr->{pkg},
            attr => [ map { { %$_ } } @{ $attr->{attr} } ],
        };
        
        # Вычисление имени
        if (ref($attr->{ref}) eq 'CODE') {
            $attr1->{name} = _find_name_of_sub_in_pkg($attr->{ref}, $attr->{pkg});
        }
        $attr1->{name} || next;
        
        # выявление дублей, если для одного и того же объекта будет два элемента в списке @attr
        my $key = ref($attr1->{ref}).'-'.$attr1->{pkg}.'-'.$attr1->{name};
        if (my $attr2 = $attr1{$key}) {
            push @{ $attr2->{attr} }, @{ $attr1->{attr} };
        }
        else {
            $attr1{$key} = $attr1;
            push @attr1, $attr1;
        }
    }
    
    return @attr1;
}

sub valid {
    if (@_) {
        @valid = @_;
        my %valid = map { (lc($_) => 1) } @valid;
    }
    
    return @valid;
};
sub clear { @attr = () }
=cut

1;
