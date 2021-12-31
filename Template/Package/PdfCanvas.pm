package Clib::Template::Package::PdfCanvas;

use strict;
use warnings;


our @SINGLE = qw/MOVETO OFFSET OFFSETX OFFSETY FONTSET QRCODE/; # ÒÅÃÈ, êîòîğûå íå îáğàçóşò áëîê - îáû÷íûé îäèíî÷íûé òåã
our %BLOCK  = (     # ÏÀĞÍÛÉ òåã (òğåáóåò çàâåğøåíèÿ áëîêà), â êà÷åñòâå çíà÷åíèÿ - õåø ñ ïàğàìåòğàìè
    FONT => {},
    STRING => {},
    AREA => {},
    ROW  => {
        ELEMENT => [qw/COL/],  # Âîçìîæíûå ıëåìåíòû âíóòğè áëîêà, îáğàáîò÷èê äëÿ êàæäîãî: tag_{TAG}_{ELEMENT}
        COL   => { is_multi => 1 },
        #END     => 'END',      # Çàâåğøàşùèé òåã
    },
);

############################
####
####    [% MOVETO x,y %]
####    Ïåğåìåùàåò êóğñîğ â óêàçàííóş òî÷êó â àáñîëşòíûõ êîîğäèíàòàõ
####
sub tag_MOVETO  {
    my ($self, $line, $head) = @_;
    
    my $formulax;
    ($formulax, $head) = $self->formula_compile($head, multi => 1);
    if (!$formulax) {
        $self->error("parse line %d: MOVETO-args format wrong (on x-variable): %s", $line, $self->error);
        return;
    }
    
    if ($head !~ s/^\s*,\s*//) {
        $self->error("parse line %d: MOVETO-args format wrong (waiting comma-separator), need: \"formula-x, formula-y\"", $line);
        return;
    }
    
    my $formulay;
    ($formulay, $head) = $self->formula_compile($head, multi => 1);
    if (!$formulay) {
        $self->error("parse line %d: MOVETO-args format wrong (on y-variable): %s", $line, $self->error);
        return;
    }
    
    $head =~ s/^\s+//;
    if ($head) {
        $self->error("parse line %d: MOVETO-args format wrong: too many params (%s)", $line, $head);
        return;
    }
    
    (line => $line, x => $formulax, y => $formulay);
}

############################
####
####    [% OFFSET x,y %]
####    Ïåğåìåùàåò êóğñîğ â óêàçàííóş òî÷êó, îòíîñèòåëüíî òåêóùåãî ìåñòîïîëîæåíèÿ
####
sub tag_OFFSET  {
    my ($self, $line, $head) = @_;
    
    my $formulax;
    ($formulax, $head) = $self->formula_compile($head, multi => 1);
    if (!$formulax) {
        $self->error("parse line %d: OFFSET-args format wrong (on x-variable): %s", $line, $self->error);
        return;
    }
    
    if ($head !~ s/^\s*,\s*//) {
        $self->error("parse line %d: OFFSET-args format wrong (waiting comma-separator), need: \"formula-x, formula-y\"", $line);
        return;
    }
    
    my $formulay;
    ($formulay, $head) = $self->formula_compile($head, multi => 1);
    if (!$formulay) {
        $self->error("parse line %d: OFFSET-args format wrong (on y-variable): %s", $line, $self->error);
        return;
    }
    
    $head =~ s/^\s+//;
    if ($head) {
        $self->error("parse line %d: OFFSET-args format wrong: too many params (%s)", $line, $head);
        return;
    }
    
    (line => $line, x => $formulax, y => $formulay);
}

sub tag_OFFSETX  {
    my ($self, $line, $head) = @_;
    
    my $formulax = $self->formula_compile($head);
    if (!$formulax) {
        $self->error("parse line %d: OFFSET-args format wrong (on x-variable): %s", $line, $self->error);
        return;
    }
    
    (line => $line, x => $formulax);
}

sub tag_OFFSETY  {
    my ($self, $line, $head) = @_;
    
    my $formulay = $self->formula_compile($head);
    if (!$formulay) {
        $self->error("parse line %d: OFFSET-args format wrong (on y-variable): %s", $line, $self->error);
        return;
    }
    
    (line => $line, y => $formulay);
}

############################
####
####    [% FONTSET name='name',size=size %]
####    Óñòàíàâëèâàåò ïàğàìåòğû øğèôòà (ïğåäûäóùèå ïàğàìåòğû òåğÿşòñÿ áåçâîçâğàòíî)
####
my  @font_param_bool = qw/bold italic underline/;
our @font_param = (qw/name size/, @font_param_bool);
our %font_param_bool = map { ($_ => 1) } @font_param_bool;
my  $font_param_regexp = join '|', @font_param;
my  $font_param_bool_regexp = join '|', @font_param_bool;

sub tag_FONTSET  {
    my ($self, $line, $head) = @_;
    
    my %f = ();
    while ($head ne '') {
        if (%f && ($head !~ s/^\s*,\s*//)) {
            $self->error("parse line %d: FONTSET-args format wrong (waiting comma-separator), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
        
        if ($head =~ s/^($font_param_regexp)\s*=\s*//io) {
            my $f = lc $1;
            my $formula;
            ($formula, $head) = $self->formula_compile($head, multi => 1);
            if (!$formula) {
                $self->error("parse line %d: FONTSET-args format wrong (on %d-th variable '%s'): %s", $line, scalar(keys %f)+1, $f, $self->error);
                return;
            }
            $f{$f} = $formula;
        }
        elsif ($head =~ s/^($font_param_bool_regexp)\s*//io) {
            my $f = lc $1;
            $f{$f} = 1;
        }
        else {
            $self->error("parse line %d: FONTSET-args format wrong (waiting valid param), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
    }
    
    (line => $line, %f);
}

sub tag_FONT {
    my ($self, $line, $head, $level) = @_;
    
    my %f = tag_FONTSET($self, $line, $head);
    %f || return;
    
    $level->{font} = { %f };
    
    return 1;
}

############################
####
####    [% AREA border=size,x=x,y=y,offsetx=offsetx,offsety=offsety,width=width,height=height,name='name',size=size %]
####    Óñòàíàâëèâàåò ïàğàìåòğû øğèôòà (ïğåäûäóùèå ïàğàìåòğû òåğÿşòñÿ áåçâîçâğàòíî)
####
sub tag_AREA  {
    my ($self, $line, $head, $level, $tag) = @_;
    
    $tag ||= 'AREA';
    
    my %f = ();
    while ($head ne '') {
        if (%f && ($head !~ s/^\s*,\s*//)) {
            $self->error("parse line %d: $tag-args format wrong (waiting comma-separator), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
        
        if ($head =~ s/^(x|y|offsetx|offsety|width|height|border|padding|paddingh|paddingv|align|$font_param_regexp)\s*=\s*//io) {
            my $f = lc $1;
            my $formula;
            ($formula, $head) = $self->formula_compile($head, multi => 1);
            if (!$formula) {
                $self->error("parse line %d: $tag-args format wrong (on %d-th variable '%s'): %s", $line, scalar(keys %f)+1, $f, $self->error);
                return;
            }
            $f{$f} = $formula;
        }
        elsif ($head =~ s/^($font_param_bool_regexp)\s*//io) {
            my $f = lc $1;
            $f{$f} = 1;
        }
        else {
            $self->error("parse line %d: $tag-args format wrong (waiting valid param), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
    }
    
    if (!$f{width}) {
        $self->error("parse line %d: $tag-args `width` is mandatory", $line);
        return;
    }
    
    $level->{f} = { %f };
    $level->{allowtxt} = 1;
    
    1;
}

sub tag_ROW {
    my ($self, $line, $head, $level) = @_;
    
    tag_AREA($self, $line, $head, $level, 'ROW') || return;

    1;
}

sub tag_ROW_COL {
    my ($self, $line, $head) = @_;
    
    my %f = ();
    while ($head ne '') {
        if (%f && ($head !~ s/^\s*,\s*//)) {
            $self->error("parse line %d: COL-args format wrong (waiting comma-separator), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
        
        if ($head =~ s/^(width|border|padding|paddingh|paddingv|align|$font_param_regexp)\s*=\s*//io) {
            my $f = lc $1;
            my $formula;
            ($formula, $head) = $self->formula_compile($head, multi => 1);
            if (!$formula) {
                $self->error("parse line %d: COL-args format wrong (on %d-th variable '%s'): %s", $line, scalar(keys %f)+1, $f, $self->error);
                return;
            }
            $f{$f} = $formula;
        }
        elsif ($head =~ s/^($font_param_bool_regexp)\s*//io) {
            my $f = lc $1;
            $f{$f} = 1;
        }
        else {
            $self->error("parse line %d: COL-args format wrong (waiting valid param), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
    }
    
    if (!$f{width}) {
        $self->error("parse line %d: COL-args `width` is mandatory", $line);
        return;
    }
    
    # Â îáğàáîò÷èêàõ ïîäıëåìåíòîâ íåò îáùåãî $level, ò.ê. îí ñâîé äëÿ êàæäîãî PARSER
    
    foreach my $prs (@{ $self->{PARSER} }) {
        my $level = $prs->level;
        
        push @{ $level->{fcol} ||= [] }, { %f };
    }
    
    1;
}
sub tag_ROW_END { 1 }



sub tag_STRING  {
    my ($self, $line, $head, $level) = @_;
    
    my %f = ();
    while (defined($head) && ($head ne '')) {
        if (%f && ($head !~ s/^\s*,\s*//)) {
            $self->error("parse line %d: STRING-args format wrong (waiting comma-separator), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
        
        if ($head =~ s/^(x|y|offsetx|offsety|$font_param_regexp)\s*=\s*//io) {
            my $f = lc $1;
            my $formula;
            ($formula, $head) = $self->formula_compile($head, multi => 1);
            if (!$formula) {
                $self->error("parse line %d: v-args format wrong (on %d-th variable '%s'): %s", $line, scalar(keys %f)+1, $f, $self->error);
                return;
            }
            $f{$f} = $formula;
        }
        elsif ($head =~ s/^($font_param_bool_regexp)\s*//io) {
            my $f = lc $1;
            $f{$f} = 1;
        }
        else {
            $self->error("parse line %d: STRING-args format wrong (waiting valid param), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
    }
    
    $level->{f} = { %f };
    $level->{allowtxt} = 1;
    
    1;
}


sub tag_QRCODE  {
    my ($self, $line, $head) = @_;
    
    my $formula;
    if (defined($head) && ($head ne '')) {
        ($formula, $head) = $self->formula_compile($head, multi => 1);
        if (!$formula) {
            $self->error("parse line %d: QRCODE-args format wrong (on variable): %s", $line, $self->error);
            return;
        }
    }
    
    my %f = (formula => $formula);
    while (defined($head) && ($head ne '')) {
        if ($head !~ s/^\s*,\s*//) {
            $self->error("parse line %d: AREA-args format wrong (waiting comma-separator), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
        
        if ($head =~ s/^(ecc|version|module|width|height)\s*=\s*//i) {
            my $f = lc $1;
            my $formula;
            ($formula, $head) = $self->formula_compile($head, multi => 1);
            if (!$formula) {
                $self->error("parse line %d: QRCODE-args format wrong (on %d-th variable '%s'): %s", $line, scalar(keys %f)+1, $f, $self->error);
                return;
            }
            $f{$f} = $formula;
        }
        else {
            $self->error("parse line %d: QRCODE-args format wrong (waiting comma-separator), need: \"param1='', ...\" (%s)", $line, $head);
            return;
        }
    }
    
    (line => $line, %f);
}


1;
