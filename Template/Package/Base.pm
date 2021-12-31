package Clib::Template::Package::Base;

use strict;
use warnings;


our @SINGLE = qw/DEFAULT RAW TEXT INCLUDE/; # ����, ������� �� �������� ���� - ������� ��������� ���
our %BLOCK  = (     # ������ ��� (������� ���������� �����), � �������� �������� - ��� � �����������
    IF  => {
        ELEMENT => [qw/ELSIF ELSE/],  # ��������� �������� ������ �����, ���������� ��� �������: tag_{TAG}_{ELEMENT}
        ELSIF   => { is_multi => 1 },
        #END     => 'END',      # ����������� ���
    },
    FOREACH => {}
);

############################
####
####    [% DEFAULT ���������� %]
####    ��� �� ���������, ������������ � �.�. ����� ��� �� ������
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
####    [% RAW ���������� %]
####    ���������� ���������� � �������� ���� (��� ����� ���� � ���������� ������������ html-����)
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
####    [% TEXT ���������� %]
####    � ��������� ���������� ������ ������������ ������������� html-����� ������������� ������� ������ ���������� �� <br />
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
    
    # � ������������ ������������ ��� ������ $level, �.�. �� ���� ��� ������� PARSER
    
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
    # �� ����� �� ������������ $level->{vars}, ������� �������� ��� $level->{varname},
    # �� ����� ������ ������, �.�. ����� $level->{vars} ���������� ��� ������������� formula � varcode,
    # �� ��� FOREACH formula - ��� �� ������ ���, � ������������.
    # ���� ��� ������, �� ��� ������ ������� ������ �������� ����� ��� ��� ������������ varsumm,
    # �� ������� var => formula, � ��� �� �����, �.�. ������ ����������� �������� ������ �� ������� ������ �� ���� ������
    # ������� ��� ������ ��������� ���������� � $level->{varname}, � formula �������� ��������� ���������� ����
    if ($head =~ s/^([a-zA-Z\_][a-zA-Z\_\d]*)\s*=\s*//) {
        $level->{vname} = $1;
        $level->{varname} = [$1]; # �� ���� ���� ���� ���� ����������� ����������
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
            # ����� ��������� ��� ����������, �� ������ ����������
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
