package Clib::Template::Package::ExcelCanvas::Excel;

use strict;
use warnings;


sub tag_MOVECELL {
    my ($prs, %p) = @_;
    
    my $col = $prs->formula_code(formula=> $p{col});
    my $row = $prs->formula_code(formula=> $p{row});
    
    $prs->content(
        '# line: '.$p{line},
        '$sub{col} = '.$col.';',
        '$sub{row} = '.$row.';',
        #'$self->_page_default(left => $sub{x}, right => $sub{x}, top => $sub{y}, bottom => $sub{y}*1.5);',
    );
}

sub tag_OFFSETCOL {
    my ($prs, %p) = @_;
    
    $prs->content(
        '# line: '.$p{line},
        '$sub{col} += '.$prs->formula_code(formula=> $p{col}).';',
        #'$self->_page_default(left => $sub{x}, right => $sub{x});'
    );
}
sub tag_OFFSETROW {
    my ($prs, %p) = @_;
    
    $prs->content(
        '# line: '.$p{line},
        '$sub{row} += '.$prs->formula_code(formula=> $p{row}).';',
        #'$self->_page_default(top => $sub{y}, bottom => $sub{y}*1.5);'
    );
}

sub _font_init {
    my ($prs, %p) = @_;
    
    my @font = ();
    no warnings 'once';
    foreach my $f (@Clib::Template::Package::PdfCanvas::font_param) {
        defined($p{$f}) || next;
        my $opt = $f eq 'name' ? 'font' : $f;
        push @font,
            ref($p{$f}) ? $f.' => ' . $prs->formula_code(formula=> $p{$f}) :
            $p{$f}      ? $f.' => ' . $p{$f} : ();
    }
    
    return '$p->{font}->set_format_properties('.join(', ', @font).');';
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
            '$sub{font} = $p->{xlsx}->add_format();',
            '$sub{font}->copy( $fontsave );',
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
    
    my %f = %{ $p{f} || {} };
    
    my @area = ();
    $f{$_} = $prs->formula_code(formula => $f{$_})
        foreach grep { exists $f{$_} } qw/border col row offsetcol offsetrow width height align/;
    push(@area, '$sub{x} = '.$f{col}.';') if defined $f{col};
    push(@area, '$sub{y} = '.$f{row}.';') if defined $f{row};
    push(@area, '$sub{x} += '.$f{offsetcol}.';') if $f{offsetcol};
    push(@area, '$sub{y} += '.$f{offsetrow}.';') if $f{offsetrow};
    
    if (exists($f{border}) || exists($f{align})) {
        
    }
    
    my $ab_height = $p{is_row} && $f{height} ? ', '.$f{height} : '';
    push(@area, '$self->_page_autobreak(\%sub'.$ab_height.');');
    push(@area, 'my ($savex, $savey) = ($sub{x}, $sub{y});');
    
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

1;
