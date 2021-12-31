package Clib::Template::Package::PdfCanvas::Pdf;

use strict;
use warnings;


sub tag_MOVETO {
    my ($prs, %p) = @_;
    
    my $x = $prs->formula_code(formula=> $p{x});
    my $y = $prs->formula_code(formula=> $p{y});
    
    $prs->content(
        '# line: '.$p{line},
        '$sub{x} = '.$x.';',
        '$sub{y} = '.$y.';',
        '$self->_page_default(left => $sub{x}, right => $sub{x}, top => $sub{y}, bottom => $sub{y}*1.5);',
    );
}

sub tag_OFFSET {
    my ($prs, %p) = @_;
    
    my @c = ();
    push(
            @c,
            '$sub{x} += '.$prs->formula_code(formula=> $p{x}).';',
            '$self->_page_default(left => $sub{x}, right => $sub{x});'
        ) if $p{x};
    push(
            @c,
            '$sub{y} += '.$prs->formula_code(formula=> $p{y}).';',
            '$self->_page_default(top => $sub{y}, bottom => $sub{y}*1.5);'
        ) if $p{y};
    
    $prs->content(
        '# line: '.$p{line},
        @c
    );
}

sub tag_OFFSETX { tag_OFFSET(@_) }
sub tag_OFFSETY { tag_OFFSET(@_) }

sub _font_init {
    my ($prs, %p) = @_;
    
    my @font = ();
    no warnings 'once';
    foreach my $f (@Clib::Template::Package::PdfCanvas::font_param) {
        defined($p{$f}) || next;
        push @font,
            ref($p{$f}) ? '$sub{font}->{'.$f.'} = ' . $prs->formula_code(formula=> $p{$f}) . ';' :
            $p{$f}      ? '$sub{font}->{'.$f.'} = ' . $p{$f} . ';' :
                            'delete $sub{font}->{'.$f.'};';
    }
    
    return @font;
}

sub tag_FONTSET {
    my ($prs, %p) = @_;
    
    $prs->content(
        '# line: '.$p{line},
        _font_init($prs, %p)
    );
}
sub tag_FONT {
    my ($prs, %p) = @_;
    
    $prs->content(
        '# line: '.$p{line},
        '{',
        [
            'my $fontsave = $sub{font};',
            'my %font = %$fontsave;',
            '$sub{font} = \%font;',
            _font_init($prs, %{ $p{f} }),
            '',
            ref($p{content}) eq 'ARRAY' ? @{ $p{content} } : $p{content},
            '$sub{font} = $fontsave;'
        ],
        '}'
    );
}


sub text_area {
    my ($prs, %p) = @_;
    
    my @text = ();
    if (my @content = $prs->chomptxt($p{content})) {
        push @text,
            'my $fontsave = $sub{font};',
            'my %font = %$fontsave;',
            '$sub{font} = \%font;',
            _font_init($prs, %{ $p{f} });
        
        push @text,
            '$sub{txt} = \'\';',
            @content,
            'my $tb  = PDF::TextBlock->new({',
            [
                'pdf    => $sub{pdf},',
                'page   => $sub{page},',
                'x      => ($sub{x}+'.($p{paddingh}||$p{padding}||0).')/mm,',
                'y      => $__h - ($sub{y})/mm - ($font{size}||(10/pt)) - ('.($p{paddingv}||$p{padding}||0).')/mm,',
            $p{width} ? (
                'w      => ('.($p{width}-2*($p{paddingh}||$p{padding}||0)).')/mm,',
            ) : (
                'w      => ('.(175-2*($p{paddingh}||$p{padding}||0)).')/mm,',
            ),
            $p{height} ? (
                'h      => ('.($p{height}-2*($p{paddingv}||$p{padding}||0)).')/mm + ($font{size}||(10/pt)),',
            ) : (),
            $p{align} ? (
                'align  => ('.$p{align}.'),',
            ) : (),
                'fonts => {',
                [
                    'default => ($sub{fobj}->{\'textblock-\'.$self->_fontkey(%font)} ||= PDF::TextBlock::Font->new({',
                    [
                        'pdf    => $sub{pdf},',
                        #'font => $sub{pdf}->corefont(\'FreeSerif\')',
                        #'font => $sub{pdf}->ttfont(\'/home/cliff/dev/ausweis/fonts/arial.ttf\'),',
                        'font => scalar $self->_pdffont(%sub),',
                        '$font{lheight} ? (lead => ($font{size}||(10/pt))*$font{lheight}) : (),',
                        'size => $font{size}||(10/pt),',
                    ],
                    '})),'
                ],
                '},'
            ],
            '});',
            '$tb->text($sub{txt});',
            '$tb->apply;',
            '$sub{txt} = \'\';',
            '$sub{font} = $fontsave;';
            
            #'my $fnt = $sub{pdf}->ttfont(\'/home/cliff/dev/ausweis/fonts/arial.ttf\');',
            #'my $txt = $sub{page}->text;',
            #'$txt->textstart;',
            #'$txt->font($fnt, 10);',
            #'$txt->translate(100,600);',
            #'$txt->fillcolor(\'black\');',
            #'$txt->text($sub{txt});',
            #'$txt->textend;',
            #'$sub{txt} = \'\';',
            #'$sub{font} = $fontsave;';
    }
    
    return @text;
}

sub tag_AREA {
    my ($prs, %p) = @_;
    
    my %f = %{ $p{f} || {} };
    
    my @area = ();
    $f{$_} = $prs->formula_code(formula => $f{$_})
        foreach grep { $f{$_} } qw/border x y offsetx offsety width height padding paddingh paddingv align/;
    push(@area, '$sub{x} = '.$f{x}.';') if defined $f{x};
    push(@area, '$sub{y} = '.$f{y}.';') if defined $f{y};
    push(@area, '$sub{x} += '.$f{offsetx}.';') if $f{offsetx};
    push(@area, '$sub{y} += '.$f{offsety}.';') if $f{offsety};
    push(@area, '$self->_page_default(left => $sub{x}, right => $sub{x});') if defined($f{x}) || $f{offsetx};
    push(@area, '$self->_page_default(top => $sub{y}, bottom => $sub{y}*1.5);') if defined($f{y}) || $f{offsety};
    my $ab_height = $p{is_row} && $f{height} ? ', '.$f{height} : '';
    push(@area, '$self->_page_autobreak(\%sub'.$ab_height.');');
    push(@area, 'my ($savex, $savey) = ($sub{x}, $sub{y});');
    if ($f{border}) {
        push @area,
            'my $gfx = $sub{page}->gfx;',
            '$gfx->save;',
            '$gfx->strokecolor('.($f{color}||'\'black\'').');',
            '$gfx->linewidth('.$f{border}.'/mm);',
            #'$gfx->linedash(1);',
            #'$gfx->move();',
            #'$gfx->line(($sub{x}+'.($f{width}||175).')/mm, ($__h-$sub{y})/mm);',
            #'$gfx->line(($sub{x}+'.($f{width}||175).')/mm, ($__h-$sub{y}-'.($f{height}||220).')/mm);',
            #'$gfx->line($sub{x}/mm, ($__h-$sub{y}-'.($f{height}||220).')/mm);',
            #'$gfx->line($sub{x}/mm, ($__h-$sub{y})/mm);',
            '$gfx->rect($sub{x}/mm, $__h-($sub{y}+'.($f{height}||220).')/mm, ('.($f{width}||175).')/mm, ('.($f{height}||220).')/mm);',
            '$gfx->stroke;',
            '$gfx->restore;';
    }
    
    my @text = text_area($prs, content => $p{content}, f => $p{f}, %f);
    
    return (\%f, @area, @text) if $p{is_row};
    
    $prs->content(
        '# line: '.$p{line},
        '{',
        [
            'my (undef, undef, undef, $__h) = $sub{page}->get_mediabox();',
            @area,
            @text,
            '$sub{x} = $savex + '.$f{width}.';',
            '$sub{y} = $savey + '.($f{height}||220).';',
        ],
        '}'
    );
}

sub tag_ROW {
    my ($prs, %p) = @_;
    
    my ($f, @area) = tag_AREA($prs, %p, is_row => 1);
    $f || return;
    
    push @area,
        '$sub{x} += '.$f->{width}.';';
    
    my @col = @{ $p{fcol}||[] };
    my $n = 0;
    foreach my $content (@{ $p{content_col}||[] }) {
        $n++;
        my $c = shift @col;
        my %f = (
            (map { ($_ => $f->{$_}) }
             grep { $f->{$_} } qw/border x y offsetx offsety width height padding paddingh paddingv align/),
            (map { ($_ => $prs->formula_code(formula => $c->{$_})) }
             grep { $c->{$_} } qw/width padding paddingh paddingv align/)
        );
        
        if ($f{border}) {
            push @area,
                '# col '.$n,
                '$gfx = $sub{page}->gfx;',
                '$gfx->save;',
                '$gfx->strokecolor('.($f->{color}||'\'black\'').');',
                '$gfx->linewidth('.$f{border}.'/mm);',
                #'$gfx->linedash(1);',
                '$gfx->move($sub{x}/mm, $__h-($sub{y}+'.($f{height}||220).')/mm);',
                '$gfx->line($sub{x}/mm + ('.($f{width}||175).')/mm, $__h-($sub{y}+'.($f{height}||220).')/mm);',
                '$gfx->line($sub{x}/mm + ('.($f{width}||175).')/mm, $__h-$sub{y}/mm);',
                '$gfx->line($sub{x}/mm, $__h-$sub{y}/mm);',
                #'$gfx->rect($sub{x}/mm, $__h-($sub{y}+'.($f{height}||220).')/mm, ('.($f{width}||175).')/mm, ('.($f{height}||220).')/mm);',
                '$gfx->stroke;',
                '$gfx->restore;';
        }
        
        push @area,
            '{',
            [ text_area($prs, content => $content, f => { %{ $p{f} }, %$c }, %f) ],
            '};',
            '$sub{x} += '.$f{width}.';',
    }
    
    $prs->content(
        '# line: '.$p{line},
        '{',
        [
            'my (undef, undef, undef, $__h) = $sub{page}->get_mediabox();',
            @area,
            '$sub{x} = $savex;',
            '$sub{y} = $savey + '.($f->{height}||15).';',
        ],
        '}'
    );
}


sub tag_STRING {
    my ($prs, %p) = @_;
    
    my %f = %{ $p{f} || {} };
    
    my @area = ();
    $f{$_} = $prs->formula_code(formula => $f{$_})
        foreach grep { $f{$_} } qw/border x y offsetx offsety/;
    push(@area, '$sub{x} = '.$f{x}.';') if $f{x};
    push(@area, '$sub{y} = '.$f{y}.';') if $f{y};
    push(@area, '$sub{x} += '.$f{offsetx}.';') if $f{offsetx};
    push(@area, '$sub{y} += '.$f{offsety}.';') if $f{offsety};
    push(@area, '$self->_page_default(left => $sub{x}, right => $sub{x});') if defined($f{x}) || $f{offsetx};
    push(@area, '$self->_page_default(top => $sub{y}, bottom => $sub{y}*1.5);') if defined($f{y}) || $f{offsety};
    
    my @text = ();
        push @text,
            'my $fontsave = $sub{font};',
            'my %font = %$fontsave;',
            '$sub{font} = \%font;',
            _font_init($prs, %{ $p{f} });
        
        push @text,
            '$sub{txt} = \'\';',
            $p{content},
            'my $fnt = $self->_pdffont(%sub);',
            '$self->_page_autobreak(\%sub, ($font{size}||10)/pt/($font{lheight}||1.8)/mm);',
            'my $txt = $sub{page}->text;',
            '$txt->textstart;',
            '$txt->font($fnt, ($font{size}||10)/pt);',
            '$txt->translate($sub{x}/mm, $__h - ($sub{y})/mm - (($font{size}||10)/pt));',
            '$txt->fillcolor(\'black\');',
            '$txt->text($sub{txt});',
            '$txt->textend;',
            '$sub{txt} = \'\';',
            '$sub{font} = $fontsave;';
    
    
    $prs->content(
        '# line: '.$p{line},
        '{',
        [
            'my (undef, undef, undef, $__h) = $sub{page}->get_mediabox();',
            @area,
            @text,
            '$sub{y} += ($font{size}||10)/pt/($font{lheight}||1.8);',
        ],
        '}'
    );
}



sub tag_QRCODE {
    my ($prs, %p) = @_;
    
    $p{text}    = $prs->formula_code(formula => $p{formula});
    $p{ecc}     = $p{ecc}       ? $prs->formula_code(formula => $p{ecc})    : '\'M\'';
    $p{version} = $p{version}   ? $prs->formula_code(formula => $p{version}): 5;
    $p{module}  = $p{module}    ? $prs->formula_code(formula => $p{module}) : 2;
    $p{width}   = $p{width}     ? $prs->formula_code(formula => $p{width})  : 40;
    $p{height}  = $p{height}    ? $prs->formula_code(formula => $p{height}) : 40;
    
    
    $prs->content(
        '# line: '.$p{line},
        'use GD::Barcode::QRcode;',
        'my $oGdB = GD::Barcode::QRcode->new('.$p{text}.', {ECC => '.$p{ecc}.', Version => '.$p{version}.', ModuleSize => '.$p{module}.'});',
        'my $oGD = $oGdB->plot();',
        '$self->_page_autobreak(\%sub);',
        'my $gdf = $sub{pdf}->image_gd($oGD);',
        'my $gfx = $sub{page}->gfx;',
        '$gfx->image( $gdf, $sub{x}/mm, 842-$sub{y}/mm-('.$p{height}.')/mm, ('.$p{width}.')/mm, ('.$p{height}.')/mm);'
    );
}

1;
