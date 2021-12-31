package Clib::Template::Package::HTTP;

use strict;
use warnings;
no warnings 'once';

our @SINGLE = qw/SCRIPT_TIME EINCLUDE PREF JSON JSONPRETTY JSONTEXT AJAX_INIT DTABLE_ATTR/; # ТЕГИ, которые не образуют блок - обычный одиночный тег
our %BLOCK  = (     # ПАРНЫЙ тег (требует завершения блока), в качестве значения - хеш с параметрами
    AJAX_SPAN  => {
        ELEMENT => [qw/ONCHANGE/],  # Возможные элементы внутри блока, обработчик для каждого: tag_{TAG}_{ELEMENT}
        #END     => 'END',      # Завершающий тег
    },
    DTABLE => {}
);

############################
####
####    [% SCRIPT_TIME %]
####    Возвращает время обработки запроса
####    Делает это в OnLine - режиме, поэтому чем позже в шиблоне это будет вставлено, тем актуальнее будет время
####
sub tag_SCRIPT_TIME {
    my ($self, $line, $head) = @_;
    
    1;
}

############################
####
####    [% EINCLUDE external_name : template_name %]
####    INCLUDE шаблона из External
####    Для инклюда внутри того же External можно не указывать external_name
####

sub tag_EINCLUDE {
    my ($self, $line, $head) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: EINCLUDE-header not defined", $line);
        return;
    }
    if ($head !~ s/^(?:([a-zA-Z\_][a-zA-Z\_\d]*)\s*\:\:?\s*)?([a-zA-Z\_][a-zA-Z\_\d\.]*)//) {
        $self->error("parse line %d: EINCLUDE-params format wrong (need: \"[var_name = ]var.source\")", $line);
        return;
    }
    my ($ext, $name) = ($1, $2);
    
    my %r = (line => $line, external => Clib::Template::Package::Parser->quote($ext), name => Clib::Template::Package::Parser->quote($name));
    
    while ($head ne '') {
        if ($head !~ s/^\s*,\s*//) {
            $self->error("parse line %d: EINCLUDE-params format wrong (waiting comma-separator), need: template_name[, varname = formula, ...]", $line);
            return;
        }
        
        my $var = {};
        push @{ $r{vars} ||= [] }, $var;
        if ($head =~ s/([a-zA-Z\_][a-zA-Z\_\d]*)\s*=\s*//) {
            $var->{name} = $1;
        }
        elsif (@{ $r{vars} } > 1) {
            # Можно указывать без переменной, но только однократно
            $self->error("parse line %d: EINCLUDE-params format wrong: allow only one non-named variable", $line);
            return;
        }
        ($var->{formula}, $head) = $self->formula_compile($head, multi => 1);
        if (!$var->{formula}) {
            $self->error("parse line %d: EINCLUDE-params format wrong (on %d-th variable): %s", $line, scalar(@{ $r{vars} }), $self->error);
            return;
        }
    }
    
    %r;
}

############################
####
####    [% EINCLUDE path/to/controller [: param1,[param2...]] %]
####    Ссылка на HTTP-обработчик
####    
####

sub tag_PREF {
    my ($self, $line, $head) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: PREF-header not defined", $line);
        return;
    }
    if ($head !~ s/^([a-zA-Z\_][a-zA-Z\_\d]*(?:\/[a-zA-Z\_][a-zA-Z\_\d]*)*)\s*//) {
        $self->error("parse line %d: PREF-params format wrong (need: \"ctrl/path[: formula, ...]\")", $line);
        return;
    }
    my $disp = $1;
    
    if (($head ne '') && ($head !~ s/^\:\s*//)) {
        $self->error("parse line %d: PREF-params format wrong (need: \"ctrl/path[: formula, ...]\", after name waiting \":\")", $line);
        return;
    }
    
    my @args = ();
    while ($head ne '') {
        if (@args) {
            if ($head !~ s/^\s*,\s*//) {
                $self->error("parse line %d: PREF-args format wrong (waiting comma-separator), need: \"ctrl/path[: formula, ...]\"", $line);
                return;
            }
        }
        
        my $formula;
        ($formula, $head) = $self->formula_compile($head, multi => 1);
        if (!$formula) {
            $self->error("parse line %d: PREF-args format wrong (on %d-th variable): %s", $line, scalar(@args)+1, $self->error);
            return;
        }
        push @args, $formula;
    }
    
    (line => $line, disp => $disp, args => \@args);
}


sub tag_JSON {
    my ($self, $line, $head) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: JSON-header not defined", $line);
        return;
    }
    require JSON::XS;
    
    my %r = ( line => $line );
    
    $r{formula} = $self->formula_compile($head);
    if (!$r{formula}) {
        $self->error("parse line %d: JSON-args format wrong: %s", $line, $self->error);
        return;
    }

    %r;
}

sub tag_JSONPRETTY { tag_JSON(@_), pretty => 1 };

sub tag_JSONTEXT { tag_JSON(@_), text => 1 };



sub tag_AJAX_INIT {
    my ($self, $line, $head) = @_;
    
    (line => $line);
}

############################
####
####    [% AJAX_SPAN var = Package::sub(formula), ... %]
####    ajax-блок, заворачиваемый в span,
####    Имя переменной обязательно, если аргументов более одного
####    Аргументов может быть несколько. В качестве каждого аргумента: генератор динамической переменной
####    Например - ссылка на функцию.
####

sub tag_AJAX_SPAN {
    my ($self, $line, $head, $level) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: AJAX_SPAN-header not defined", $line);
        return;
    }
    
    if ($head =~ s/^([a-zA-Z\_][a-zA-Z\_\d]*)\s*\:\s*//) {
        $level->{key} = $1;
    }
    
    my $keyh = ($self->{TMP}->{AJAX_KEY}||={});
    # AJAX_KEY - это ключи для JS-кодов для обновления разных кусков страницы, они должны иметь полную уникальность в пределах всей страницы
    if ($level->{key}) {
        # В случае явного указания KEY (имени слоя и функции апдейтера) мы не будем ему приписывать сложные префиксы для уникальности,
        # Но надо помнить, что тут мы хоть и проверяем эту уникальность - но только в рамках текущего шаблона.
        # Если будем использовать инклюды и наследования, могут возникнуть коллизии
        if ($keyh->{$level->{key}}) {
            $self->error("parse line %d: AJAX_SPAN: duplicate block key '%s'", $line, $level->{key});
            return;
        }
    }
    else {
        my $n = 1;
        $n++ while $keyh->{sprintf('_%03d', $n)};
        $level->{key} = sprintf('_%03d', $n);
        $level->{key_is_rand} = 1;
    }
    $level->{idprefix} = 'ajax_span__';
    $level->{id} = $level->{idprefix}.$level->{key}; # id span-слоя
    
    # Можно указать опции в квадратных скобках
    my $opts = ($level->{opts} = {});
    if ($head =~ s/^\[([a-zA-Z\_][a-zA-Z\_\d \,]*)\]\s*//) {
        my @opts = split /\s*\,\s*/, $1;
        if (my @wrong = grep { !/^(hidden|paused|empty)$/ } @opts) {
            $self->error("parse line %d: AJAX_SPAN: unknown options: %s", $line, join(', ', @wrong));
            return;
        }
        $opts->{$_} = 1 foreach @opts;
        $opts->{paused} = 1 if $opts->{hidden}; # Если слой будет скрытым, то его не надо обновлять
        #$opts->{empty} = 1 if $opts->{hidden}; # А вот пустым его по умолчанию делать не будем, возможно тамошние элементы нужны
    }
    
    # Смотрим используемые переменные
    $level->{vars} = [];
    while ($head ne '') {
        my $var = { };
        if ($head =~ s/^([a-zA-Z\_][a-zA-Z\_\d]*)\s*\=\s*//) {
            $var->{name} = $1;
        }
        if ($head =~ s/^([a-zA-Z][a-zA-Z\d\_]*(?:\:\:[a-zA-Z][a-zA-Z\d\_]*)*)\s*//) {
            $var->{type} = 'code';
            $var->{func} = $1;
        }
        else {
            $self->error("parse line %d: AJAX_SPAN-params syntax error near: %s", $line, $head);
            return;
        }
        if ($head =~ s/^\(\s*//) {
            my $formula;
            ($formula, $head) = $self->formula_compile($head, multi => 1);
            if (!$head || ($head !~ s/\s*\)//)) {
                $self->error("parse line %d: AJAX_SPAN-params syntax error near: %s", $line, $head);
                return;
            }
            
            $var->{formula} = $formula if $formula;
        }
        
        push @{ $level->{vars} }, $var;
        
        if ($head =~ s/^,\s*//) {
            if ($head eq '') {
                $self->error("parse line %d: AJAX_SPAN-params format: no args after coma", $line);
                return;
            }
        }
        else {
            $head =~ s/\s*//;
        }
    }
    if ($head ne '') {
        $self->error("parse line %d: AJAX_SPAN-params syntax error near: %s", $line, $head);
        return;
    }
    
    # Динамические переенные быть обязаны, т.к. это первичный признак необходимости перерисовки блока
    if (!@{ $level->{vars} }) {
        $self->error("parse line %d: AJAX_SPAN-params not found", $line);
        return;
    }
    if ((@{ $level->{vars} } > 1) && (grep { !$_->{name} } @{ $level->{vars} })) {
        $self->error("parse line %d: AJAX_SPAN-params no var-names with many args", $line);
        return;
    }
    
    1;
}

sub tag_AJAX_SPAN_ONCHANGE { 1 }

sub tag_AJAX_SPAN_END { 1 }



sub tag_DTABLE {
    my ($self, $line, $head, $level) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: DTABLE-header not defined", $line);
        return;
    }
    my $var = ($level->{vars} = {});
    if ($head =~ s/^([a-zA-Z\_][a-zA-Z\_\d]*)\s*=\s*//) {
        $var->{name} = $1;
    }
    
    if ($head =~ s/^\s*([^\s]+)\s*//) {
        $level->{dtbl} = $1;
    }
    else {
        $self->error("parse line %d: DTABLE-formula format([var = ] dtable_key) wrong near: %s", $line, $head);
        return;
    }
    
    1;
}
sub tag_DTABLE_END { 1 }

sub tag_DTABLE_ATTR {
    my ($self, $line, $head) = @_;
    
    my %r = ( line => $line );
    
    if ($head !~ /^\s*$/) {
        $r{formula} = $self->formula_compile($head);
        if (!$r{formula}) {
            $self->error("parse line %d: DTABLE_ATTR-args format wrong: %s", $line, $self->error);
            return;
        }
    }

    %r;
}


1;
