package Clib::Template::Package::Block;

use strict;
use warnings;


our @SINGLE = qw/BLOCKDUP BLOCKINCLUDE/; # ТЕГИ, которые не образуют блок - обычный одиночный тег
our %BLOCK  = (     # ПАРНЫЙ тег (требует завершения блока), в качестве значения - хеш с параметрами
    BLOCK  => {
        #ELEMENT => [qw/ONLOAD/],  # Возможные элементы внутри блока, обработчик для каждого: tag_{TAG}_{ELEMENT}
        #END     => 'END',      # Завершающий тег
    },
);


sub tag_BLOCK {
    my ($self, $line, $head, $level) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: BLOCK-header not defined", $line);
        return;
    }
    if ($head !~ s/^([a-zA-Z][a-zA-Z\_\d]*)\s*//) {
        $self->error("parse line %d: BLOCK-params format wrong (need: \"block_name[: [var_name = ]formula, ...]\")", $line);
        return;
    }
    
    $level->{sub} = $1;
    
    if (($head ne '') && ($head !~ s/^\:\s*//)) {
        $self->error("parse line %d: BLOCK-params format wrong (need: \"block_name[: [var_name = ]formula, ...]\", after name waiting \":\")", $line);
        return;
    }
    
    #if ($3) {
    #    ($level->{vname}, $level->{vsrc}) = ($2, $3);
    #    $level->{var} = defined $level->{vname} ? $level->{vname} : '';
    #    $level->{vpath} = [$self->vpath($level->{vsrc})];
    #    $blk->{vname} = $level->{vname};
    #}
    while ($head ne '') {
        if (@{ $level->{vars}||[] }) {
            if ($head !~ s/^\s*,\s*//) {
                $self->error("parse line %d: BLOCK-params format wrong (waiting comma-separator), need: \"block_name[: [var_name = ]formula, ...]\"", $line);
                return;
            }
        }
        
        my $var = { };
        push @{ $level->{vars} ||= [] }, $var;
        if ($head =~ s/^([a-zA-Z\_][a-zA-Z\_\d]*)\s*=\s*//) {
            $var->{name} = $1;
        }
        ($var->{formula}, $head) = $self->formula_compile($head, multi => 1);
        if (!$var->{formula}) {
            $self->error("parse line %d: BLOCK-params format wrong (on %d-th variable): %s", $line, scalar(@{ $level->{vars} }), $self->error);
            return;
        }
    }
    
    my $blk = ($self->{TMP}->{BLOCK}||={});
    if ($blk->{lc $level->{sub}}) {
        $self->error("parse line %d: Duplicate BLOCK '%s'. Use BLOCKDUP to duplicate exist data", $line, $level->{sub});
        return;
    }
    $blk = ($blk->{lc $level->{sub}} = { name => $level->{sub}, line => $line });
    $blk->{varname} = { map { ($_->{name} => 1) } grep { $_->{name} } @{ $level->{vars} || [] } };

    1;
}

sub tag_BLOCK_END { 1 }

sub tag_BLOCKDUP {
    my ($self, $line, $head) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: BLOCK-header not defined", $line);
        return;
    }
    if ($head !~ s/^([a-zA-Z][a-zA-Z\_\d]+)\s*//) {
        $self->error("parse line %d: BLOCKDUP-params format wrong (need: \"block_name(formulas ...)\")", $line);
        return;
    }
    my $name = $1;
    
    my $blk = ($self->{TMP}->{BLOCK}||{})->{lc $name};
    if (!$blk) {
        $self->error("parse line %d: BLOCK '%s' not defined", $line, $name);
        return;
    }

    my %r = (line => $line, %$blk);
    delete $r{vars};
    delete $r{varname};
    
    while ($head ne '') {
        if (@{ $r{vars}||[] }) {
            if ($head !~ s/^\s*,\s*//) {
                $self->error("parse line %d: BLOCKDUP-params format wrong (near: '%s', waiting comma-separator), need: \"block_name(formulas ...)\"", $line, $head);
                return;
            }
        }
        else {
            if ($head !~ s/^\s*\(\s*//) {
                $self->error("parse line %d: BLOCKDUP-params format wrong (waiting '('), need: \"block_name(formulas ...)\"", $line);
                return;
            }
            if ($head !~ s/\s*\)\s*$//) {
                $self->error("parse line %d: BLOCKDUP-params format wrong at end-line", $line);
                return;
            }
        }
        
        my $var = { };
        push @{ $r{vars} ||= [] }, $var;
        if ($head =~ s/^([a-zA-Z\_][a-zA-Z\_\d]*)\s*=\s*//) {
            $var->{name} = $1;
            if (!($blk->{varname} || {})->{$var->{name}}) {
                $self->error("parse line %d: BLOCKDUP-params: variable '%s' not defined in block `%s`", $line, $var->{name}, $name);
                return;
            }
        }
        elsif (@{ $r{vars} } > 1) {
            # Можно указывать без переменной, но только однократно
            $self->error("parse line %d: BLOCKDUP-params format wrong: allow only one non-named variable", $line);
            return;
        }
        elsif (!$blk->{varname} || (keys(%{ $blk->{varname} }) != 1)) {
            # Безымнная переменная может быть только если у нас всего одна переменная в блоке используется
            # если переменных в блоке не используется совсем, тогда и передавать в него ничего не можем
            $self->error("parse line %d: BLOCKDUP-params format wrong: not allow variables in block `%s`", $line, $name);
            return;
        }
        elsif (my ($name) = keys(%{ $blk->{varname} || {} })) {
            # Если используется только одна безымянная переменная, укажем ей имя, если оно указано в блоке
            $var->{name} = $name;
        }
        ($var->{formula}, $head) = $self->formula_compile($head, multi => 1);
        if (!$var->{formula}) {
            $self->error("parse line %d: BLOCKDUP-params format wrong (on %d-th variable): %s", $line, scalar(@{ $r{vars} }), $self->error);
            return;
        }
    }
    
    %r;
}

sub tag_BLOCKINCLUDE {
    my ($self, $line, $head) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: BLOCKINCLUDE-header not defined", $line);
        return;
    }
    
    my %r = (line => $line);
    
    if ($head !~ s/^([a-zA-Z\_][a-zA-Z\_\d\.]*)\s*//) {
        $self->error("parse line %d: BLOCKINCLUDE-params format wrong (waiting template name), need: template_name: block_name[, varname = formula]", $line);
        return;
    }
    
    $r{name} = Clib::Template::Package::Parser->quote($1);
    
    if (($head ne '') && ($head !~ s/^\:\s*//)) {
        $self->error("parse line %d: BLOCKINCLUDE-params format wrong (waiting \":\"), need: template_name: block_name[, varname = formula]", $line);
        return;
    }
    
    if ($head !~ s/^([a-zA-Z\_][a-zA-Z\_\d\.]*(?:\/[a-zA-Z\_][a-zA-Z\_\d\.]*)*)\s*//) {
        $self->error("parse line %d: BLOCKINCLUDE-params format wrong (waiting block name), need: template_name: block_name[, varname = formula]", $line);
        return;
    }
    
    $r{block} = $1;
    $r{block} =~ s/\//_/g;
    
    while ($head ne '') {
        if ($head !~ s/^\s*,\s*//) {
            $self->error("parse line %d: BLOCKINCLUDE-params format wrong (waiting comma-separator), need: template_name[, varname = formula]", $line);
            return;
        }
        
        my $var = {};
        push @{ $r{vars} ||= [] }, $var;
        if ($head =~ s/([a-zA-Z\_][a-zA-Z\_\d]*)\s*=\s*//) {
            $var->{name} = $1;
        }
        elsif (@{ $r{vars} } > 1) {
            # Можно указывать без переменной, но только однократно
            $self->error("parse line %d: BLOCKINCLUDE-params format wrong: allow only one non-named variable", $line);
            return;
        }
        ($var->{formula}, $head) = $self->formula_compile($head, multi => 1);
        if (!$var->{formula}) {
            $self->error("parse line %d: BLOCKINCLUDE-params format wrong (on %d-th variable): %s", $line, scalar(@{ $r{vars} }), $self->error);
            return;
        }
    }
    
    %r;
}

1;
