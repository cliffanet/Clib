package Clib::Template::Package::Pdf;

use 5.008008;
use strict;
use warnings;

our $VERSION = '1.0';

use base 'Clib::Template::Package::Parser';


sub init {
    my $self = shift;
    
    $self->SUPER::init(@_);
    
    $self->level_new(sub => 'pdf', vars => {  }, line => 1);
    
    return $self;
}

my %content_builder = (
    
    INIT  => sub {
        my ($self, $bld) = @_;
        # ��� ������������� ����
        $bld->{scalar} = 0;
        return
            "    my \%sub = \$self->_sub_beg();";
    },
    
    #''  => sub {                                # perl-���
    #    my ($self, $bld, $content, $indent) = @_;
    #    
    #    # ������� �������� ���� ����. ���� ��������� ��������� _builder_scalar,
    #    # ������� �������� ��������� ���������� ��������� ������
    #    my $bscalar = $bld->{scalar};
    #    $bld->{scalar} = 0;
    #    #if ($bscalar < 0) {                     # �� ����� ���� ��������� "$result = " � ������ ������ - ���� ��� �������
    #    #    return "'';\n" . $indent . $content;
    #    #}
    #    #els
    #    if ($bscalar == 0) {                 # �� ����� ���� ��������� ���-�� ������, �� �� ����������� result
    #                                            # (��������, ������ ��� ����� �����) - ����� ��������� ���
    #                                            # ������ ����� ����� ���
    #        return "\n" . $indent . $content;
    #    }
    #    elsif ($bscalar == 1) {                 # �� ����� ���������� ����� �� ������, ���� ������� ����������
    #        return ";\n" . $indent . $content;
    #    }
    #    
    #    return $indent . $content . "\n";
    #},
    
    SCALAR  => sub {                            # ���� perl-���, �� � ���� ��������, ������� ���� ��������� � result
        my ($self, $bld, $content, $indent) = @_;     # ���� ��� ��������� ������, �� ��� �.�. ������������
        
        my $bscalar = $bld->{scalar};
        $bld->{scalar} = 1;
        if ($bscalar < 0) {                     # �� ����� ���� ��������� "$result = " � ������ ������
            return "\n" . $indent . "    " . $$content;
        }
        elsif ($bscalar == 0) {                 # �� ����� ���� ��������� ���-�� ������, �� �� ����������� result
                                                # (��������, ������ ��� ����� �����) - ����� ��������� ���
            return "\n$indent\$sub{txt} .= \n$indent    " . $$content;
        }
        elsif ($bscalar == 1) {                 # �� ����� ���������� ����� �� ������, ������� ������ ������ ���������� � ����������
            return "\n$indent  . " . $$content;
        }
        "# !!!!!!!!! %content_builder{SCALAR}: Error processing !!!!!!!!";
    },
    
    FINISH  => sub {
        my ($self, $bld) = @_;
        # ��� ���������� ������ _builder_scalar
        # ��������� ������� �������� perl-����, �� �������
        return
            $self->content_builder('')->($self, $bld, '', '    ') ."\n" .
            "    return \$self->_sub_end;\n";
    }
);

sub content_builder {
    my $self = shift;
    
    @_ ||  return $self->SUPER::content_builder(), %content_builder;
    
    return $content_builder{ $_[0] } || $self->SUPER::content_builder(@_);
}

sub content_build {
    my $self = shift;
    
    my $code = $self->SUPER::content_build(@_) || return;
    
    return '
    use PDF::API2;
    use PDF::TextBlock;

    use constant mm => 25.4 / 72;
    use constant in => 1 / 72;
    use constant pt => 1;
    
    sub _sub_beg {
        my $self = shift;
        my $p = ($self->{_pdf} ||= {
            level => 0,
            pdf => PDF::API2->new(),
            txt => \'\',
            x => 0,
            y => 0,
            font => {},
            fobj => {},
            popts => {},
        });
        $p->{pdf}->mediabox(\'A4\');
        $p->{page} = $p->{pdf}->page();
        
        $p->{level} ++;
        
        return %$p;
    }
    
    sub _sub_end {
        my $self = shift;
        my $p = $self->{_pdf} || return;
        
        $p->{level} --;
        
        return \'\' if $p->{level} > 0;
        
        delete $self->{_pdf};
        
        return $p->{pdf}->stringify();
    }
    
    sub _pdffont {
        my ($self, %sub) = @_;
        my $pdf = $sub{pdf} || return;
        my $font = $sub{font} || return;
        my $name = $font->{name} || \'arial.ttf\';
        my $filedir = '.$self->quote($self->{CONFIG}->{FILE_DIR}).';
        my $key = $self->_fontkey(%$font);
        
        if ($name =~ /\.(ttf)$/) {
            my $meth;
            if ($1 eq \'ttf\') {
                $meth = \'ttfont\';
            }
            
            return $sub{fobj}->{$key} ||= $pdf->$meth($filedir . \'/\' . $name);
        }
        
        return $sub{fobj}->{$key} ||= $pdf->corefont($name);
    }
    
    
    sub _fontkey {
        my ($self, %font) = @_;
        return join \';\', map { $_.\'=\'.$font{$_} } sort keys %font;
    }
    
    sub _page_default {
        my ($self, %p) = @_;
        
        my $p = $self->{_pdf} || return;
        $p = ($p->{popts} ||= {});
        
        foreach my $k (keys %p) {
            next if defined $p->{$k};
            $p->{$k} = $p{$k};
        }
        return %$p;
    }
    
    sub _page_autobreak {
        my ($self, $sub, $height) = @_;
        
        $sub || return;
        $height ||= 0;
        
        my $page = ($sub->{popts} || {});
        
        $sub->{page} || return;
        my (undef, undef, undef, $h) = $sub->{page}->get_mediabox();
        
        if ($h-$sub->{y}/mm-($page->{bottom}||0)/mm < $height) {
            $sub->{pdf} || return;
            $sub->{page} = $sub->{pdf}->page();
            $sub->{y} = $page->{top}||0;
            return 1;
        }
        
        return 0;
    }
    
    '."\n".   
    $code;
}


sub content_text {
    my ($self, $text) = @_;
    
    return if !defined($text);
    return $self->content()
        if ($text eq '') || !$self->allowtxt;
    
    return $self->content(\ $self->quote($text));
}

sub allowtxt {
    # ���������� ������ ����� � ���� �����.
    # ����������, ����� ��������� ������������ ���������� $sub{txt} � ����� ������� ������,
    # � ��� ��, ���, ��� ��� �� ����
    my $self = shift;
    
    foreach my $level (@{ $self->{_level} }) {
        next if !defined($level->{allowtxt});
        return $level->{allowtxt};
    }
    
    return;
}

sub chomptxt {
    # ��� ������� ��������� �������� ������� � ������ � �����
    my ($self, $content) = @_;
    
    $content || return;
    return $content if ref($content) ne 'ARRAY';
    my @content = @$content; # ��� �������� � ��������� �������
    
    my $first = $content[0];
    if (ref($first) eq 'SCALAR') {
        my $txt = $$first;
        if (($txt =~ /^\'/) && ($txt =~ /\'$/) && ($txt =~ s/^(\')\s+/$1/)) {
            if ($txt =~ /^\'\'$/) {
                shift @content;
            }
            else {
                $content[0] = \$txt;
            }
        }
    }
    
    @content || return;
    
    my $last = $content[@content - 1];
    if (ref($last) eq 'SCALAR') {
        my $txt = $$last;
        if (($txt =~ /^\'/) && ($txt =~ /\'$/) && ($txt =~ s/\s+(\')$/$1/)) {
            if ($txt =~ /^\'\'$/) {
                pop @content;
            }
            else {
                $content[@content - 1] = \$txt;
            }
        }
    }
    
    return @content;
}


1;
