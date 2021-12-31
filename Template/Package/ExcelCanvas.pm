package Clib::Template::Package::ExcelCanvas;

use strict;
use warnings;

use Clib::Template::Package::PdfCanvas;

our @SINGLE = qw/MOVECELL OFFSETCOL OFFSETROW FONTSET/; # ����, ������� �� �������� ���� - ������� ��������� ���
our %BLOCK  = (     # ������ ��� (������� ���������� �����), � �������� �������� - ��� � �����������
    FONT => {},
    ROW  => {
        ELEMENT => [qw/COL/],  # ��������� �������� ������ �����, ���������� ��� �������: tag_{TAG}_{ELEMENT}
        COL   => { is_multi => 1 },
        #END     => 'END',      # ����������� ���
    },
);

############################
####
####    [% MOVECELL x,y %]
####    ���������� ������ � ��������� ������: �������, ���
####
sub tag_MOVECELL  {
    my ($self, $line, $head) = @_;
    
    my $formulacol;
    ($formulacol, $head) = $self->formula_compile($head, multi => 1);
    if (!$formulacol) {
        $self->error("parse line %d: MOVECELL-args format wrong (on col-variable): %s", $line, $self->error);
        return;
    }
    
    if ($head !~ s/^\s*,\s*//) {
        $self->error("parse line %d: MOVECELL-args format wrong (waiting comma-separator), need: \"formula-col, formula-row\"", $line);
        return;
    }
    
    my $formularow;
    ($formularow, $head) = $self->formula_compile($head, multi => 1);
    if (!$formularow) {
        $self->error("parse line %d: MOVECELL-args format wrong (on row-variable): %s", $line, $self->error);
        return;
    }
    
    $head =~ s/^\s+//;
    if ($head) {
        $self->error("parse line %d: MOVECELL-args format wrong: too many params (%s)", $line, $head);
        return;
    }
    
    (line => $line, col => $formulacol, row => $formularow);
}

############################
####
####    [% OFFSET col,row %]
####    ���������� ������ � ��������� ������, ������������ �������� ��������������
####
sub tag_OFFSETCOL  {
    my ($self, $line, $head) = @_;
    
    my $formulacol = $self->formula_compile($head);
    if (!$formulacol) {
        $self->error("parse line %d: OFFSET-args format wrong (on col-variable): %s", $line, $self->error);
        return;
    }
    
    (line => $line, col => $formulacol);
}

sub tag_OFFSETROW {
    my ($self, $line, $head) = @_;
    
    my $formularow = $self->formula_compile($head);
    if (!$formularow) {
        $self->error("parse line %d: OFFSET-args format wrong (on row-variable): %s", $line, $self->error);
        return;
    }
    
    (line => $line, row => $formularow);
}

############################
####
####    [% FONTSET name='name',size=size %]
####    ������������� ��������� ������ (���������� ��������� �������� ������������)
####
sub tag_FONTSET     { Clib::Template::Package::PdfCanvas::tag_FONTSET(@_); }

sub tag_FONT        { Clib::Template::Package::PdfCanvas::tag_FONT(@_); }

sub tag_ROW         { Clib::Template::Package::PdfCanvas::tag_ROW(@_); }

sub tag_ROW_COL     { Clib::Template::Package::PdfCanvas::tag_ROW_COL(@_); }
sub tag_ROW_END     { 1 }

1;
