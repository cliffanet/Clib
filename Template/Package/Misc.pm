package Clib::Template::Package::Misc;

use strict;
use warnings;

use Clib::DT;
use Clib::Num;


our @SINGLE = qw/DATETIME DATE SIZE BYTE INTERVAL DUMPER CSV/; # ����, ������� �� �������� ���� - ������� ��������� ���
our %BLOCK  = (     # ������ ��� (������� ���������� �����), � �������� �������� - ��� � �����������
    #BLOCK  => {
    #    ELEMENT => [qw/ONLOAD/],  # ��������� �������� ������ �����, ���������� ��� �������: tag_{TAG}_{ELEMENT}
    #    #END     => 'END',      # ����������� ���
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
