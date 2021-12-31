package Clib::Template::Package::Base;

use strict;
use warnings;


our @SINGLE = qw/DEFAULT RAW TEXT INCLUDE/; # ТЕГИ, которые не образуют блок - обычный одиночный тег
our %BLOCK  = (     # ПАРНЫЙ тег (требует завершения блока), в качестве значения - хеш с параметрами
    IF  => {
        ELEMENT => [qw/ELSIF ELSE/],  # Возможные элементы внутри блока, обработчик для каждого: tag_{TAG}_{ELEMENT}
        ELSIF   => { is_multi => 1 },
        #END     => 'END',      # Завершающий тег
    },
    FOREACH => {}
);

############################
####
####    [% DEFAULT переменная %]
####    Тэг по умолчанию, используется в т.ч. когда тэг не указан
####
sub tag_DEFAULT  {
    my ($self, $line, $head) = @_;
    
    $head =~ s/^\s+//;
    my $formula = $self->formula_compile($head);
    if (!$formula) {
        $self->error("parse line %d on formula: %s", $line, $self->error);
        return;
    }
    
    (formula => $formula);
}

############################
####
####    [% RAW переменная %]
####    Возвращает переменную в исходном виде (без этого тега в переменной экранируются html-теги)
####
sub tag_RAW  {
    my ($self, $line, $head) = @_;
    
    $head =~ s/^\s+//;
    my $formula = $self->formula_compile($head);
    if (!$formula) {
        $self->error("parse line %d on formula: %s", $line, $self->error);
        return;
    }
    
    (formula => $formula);
}

############################
####
####    [% TEXT переменная %]
####    В указанной переменной помимо стандартного экранирования html-тегов дополнительно перевод строки заменяется на <br />
####
sub tag_TEXT  {
    my ($self, $line, $head) = @_;
    
    $head =~ s/^\s+//;
    my $formula = $self->formula_compile($head);
    if (!$formula) {
        $self->error("parse line %d on formula: %s", $line, $self->error);
        return;
    }
    
    (formula => $formula);
}


sub tag_IF {
    my ($self, $line, $head, $level) = @_;
    
    $head =~ s/\s+$//;
    if (!$head) {
        $self->error("parse line %d: IF-condiiton not defined", $line);
        return;
    }
    $level->{formula} = $self->formula_compile('istrue('.$head.')');
    if (!$level->{formula}) {
        $self->error("parse line %d on IF-condiiton: %s", $line, $self->error);
        return;
    }

    1;
}

sub tag_IF_ELSE { 1 }
sub tag_IF_ELSIF {
    my ($self, $line, $head) = @_;
        
    $head =~ s/\s+$//;
    if (!$head) {
        $self->error("parse line %d: IF-condiiton not defined", $line);
        return;
    }
    my $formula = $self->formula_compile('istrue('.$head.')');
    if (!$formula) {
        $self->error("parse line %d: %s", $line, $self->error);
        return;
    }
    
    # В обработчиках подэлементов нет общего $level, т.к. он свой для каждого PARSER
    
    foreach my $prs (@{ $self->{PARSER} }) {
        my $level = $prs->level;
        
        if ($level->{else}) {
            $self->error("parse line %d: ELSE must be after ELSIF only", $line);
            return;
        }
        push @{ $level->{formula_elsif} ||= [] }, $formula;
    }
    
    1;
}
sub tag_IF_END { 1 }


sub tag_FOREACH {
    my ($self, $line, $head, $level) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: FOREACH-header not defined", $line);
        return;
    }
    # До этого мы использовали $level->{vars}, который создавал сам $level->{varname},
    # но этого делать нельзя, т.к. через $level->{vars} переменной ещё присваивается formula и varcode,
    # но для FOREACH formula - это не совсем код, её определяющий.
    # Если его задать, то при вызове функций внутри текущего блока или при формировании varsumm,
    # мы получим var => formula, а это не верно, т.к. вместо конкретного элемента списка мы получим ссылку на весь список
    # Поэтому тут просто добавляем переменную в $level->{varname}, а formula сохраним отдельным параметром слоя
    if ($head =~ s/^([a-zA-Z\_][a-zA-Z\_\d]*)\s*=\s*//) {
        $level->{vname} = $1;
        $level->{varname} = [$1]; # на этом слое есть одна объявленная переменная
    }
    
    $level->{formula} = $self->formula_compile($head);
    if (!$level->{formula}) {
        $self->error("parse line %d: FOREACH-formula format wrong: %s", $line, $self->error);
        return;
    }
    
    1;
}
sub tag_FOREACH_END { 1 }

sub tag_INCLUDE {
    my ($self, $line, $head) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: INCLUDE-header not defined", $line);
        return;
    }
    
    if ($head !~ s/^([a-zA-Z\_][a-zA-Z\_\d\.]*)//) {
        $self->error("parse line %d: INCLUDE-params format wrong, need: template_name[, varname = formula]", $line);
        return;
    }
    
    my %r = (name => Clib::Template::Package::Parser->quote($1));
    
    while ($head ne '') {
        if ($head !~ s/^\s*,\s*//) {
            $self->error("parse line %d: INCLUDE-params format wrong (waiting comma-separator), need: template_name[, varname = formula]", $line);
            return;
        }
        
        my $var = {};
        push @{ $r{vars} ||= [] }, $var;
        if ($head =~ s/([a-zA-Z\_][a-zA-Z\_\d]*)\s*=\s*//) {
            $var->{name} = $1;
        }
        elsif (@{ $r{vars} } > 1) {
            # Можно указывать без переменной, но только однократно
            $self->error("parse line %d: INCLUDE-params format wrong: allow only one non-named variable", $line);
            return;
        }
        ($var->{formula}, $head) = $self->formula_compile($head, multi => 1);
        if (!$var->{formula}) {
            $self->error("parse line %d: INCLUDE-params format wrong (on %d-th variable): %s", $line, scalar(@{ $r{vars} }), $self->error);
            return;
        }
    }
    
    %r;
}

1;
