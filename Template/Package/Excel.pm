package Clib::Template::Package::Excel;

use 5.008008;
use strict;
use warnings;

our $VERSION = '1.0';

use base 'Clib::Template::Package::Pdf';


sub init {
    my $self = shift;
    
    $self->Clib::Template::Package::Parser::init(@_);
    
    $self->level_new(sub => 'excel', vars => {  }, line => 1);
    
    return $self;
}

sub content_build {
    my $self = shift;
    
    my $code = $self->Clib::Template::Package::Parser::content_build(@_) || return;
    
    return '
    use Excel::Writer::XLSX;
    
    sub _sub_beg {
        my $self = shift;
        my $p = ($self->{_excel} ||= {
            level => 0,
            bin => undef,
            txt => \'\',
            col => 0,
            row => 0,
            fobj => {},
            popts => {},
        });
        my $fh;
        open($fh, \'>\', \($p->{bin}));
        $p->{xlsx} = Excel::Writer::XLSX->new( $fh );
        $p->{font} = $p->{xlsx}->add_format();
        
        $p->{level} ++;
        
        return %$p;
    }
    
    sub _sub_end {
        my $self = shift;
        my $p = $self->{_excel} || return;
        
        $p->{level} --;
        
        return \'\' if $p->{level} > 0;
        
        $p->{xlsx}->close;
        delete $self->{_pdf};
        
        return $p->{bin};
    }
    
    sub _excel_font {
        my ($self, %sub) = @_;
        my $xls = $sub{xlsx} || return;
        my $font = $sub{font} || return;
        my $key = $self->_fontkey(%$font);
        
        return $sub{fobj}->{$key} ||= $pdf->corefont($name);
    }
    
    
    sub _fontkey {
        my ($self, %font) = @_;
        return join \';\', map { $_.\'=\'.$font{$_} } sort keys %font;
    }
    
    '."\n".   
    $code;
}


1;
