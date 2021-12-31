package Clib::Template::Package::Misc;

use strict;
use warnings;

use Clib::DT;
use Clib::Num;


our @SINGLE = qw/DATETIME DATE SIZE BYTE INTERVAL DUMPER CSV/; # ТЕГИ, которые не образуют блок - обычный одиночный тег
our %BLOCK  = (     # ПАРНЫЙ тег (требует завершения блока), в качестве значения - хеш с параметрами
    #BLOCK  => {
    #    ELEMENT => [qw/ONLOAD/],  # Возможные элементы внутри блока, обработчик для каждого: tag_{TAG}_{ELEMENT}
    #    #END     => 'END',      # Завершающий тег
    #},
);


sub tag_DATETIME {
    my ($self, $line, $head) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: DATETIME-header not defined", $line);
        return;
    }
    
    my %r = ( line => $line );
    
    $r{formula} = $self->formula_compile($head);
    if (!$r{formula}) {
        $self->error("parse line %d: DATETIME-args format wrong: %s", $line, $self->error);
        return;
    }

    %r;
}


sub tag_DATE { tag_DATETIME(@_) }

sub tag_formula {
    my ($tag, $self, $line, $head) = @_;
    
    if (!defined($head)) {
        $self->error("parse line %d: %s-header not defined", $line, $tag);
        return;
    }
    
    my %r = ( line => $line );
    
    $r{formula} = $self->formula_compile($head);
    if (!$r{formula}) {
        $self->error("parse line %d: %s-args format wrong: %s", $line, $tag, $self->error);
        return;
    }

    %r;
}

sub tag_SIZE { tag_formula( SIZE => @_ ); }
sub tag_BYTE { tag_formula( BYTE => @_ ); }

sub tag_INTERVAL { tag_formula( INTERVAL => @_ ); }

sub tag_DUMPER { tag_formula( DUMPER => @_ ); }


sub tag_CSV { tag_formula( CSV => @_ ); }


1;
