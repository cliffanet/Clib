package Clib::Num;

use strict;
use warnings;

=pod

=encoding UTF-8

=head1 NAME

Clib::Num - Форматирование чисел в удобный для восприятия формат

=head1 SYNOPSIS
    
    use Clib::Num;
    
    print Clib::Num::byte(1024);

=head1 Функции

Функции этого модуля не импортируются в namespace модуля, в котором мы работаем.

Поэтому вызов требует указания имени модуля:

    Clib::Num::byte(...);

=cut

=head2 byte($dig)
    
Красивое отображение с округлением до порядка по базе 1024. Например:

    my $byte = 1024*128;
    
    print Clib::Num::byte($byte);
    
    # Будет напечатано: 128 k

=cut

sub byte {
    my $byte = shift;
    
    return $byte if !$byte || ($byte !~ /^\d+(\.\d+)?$/);
    
    $byte = sprintf('%.2f', $byte) if $1;
    
    if ($byte >= 1099511627776) {
        return sprintf ('%.1f T', $byte / 1099511627776);
    }
    elsif ($byte >= 1073741824) {
        return sprintf ('%.1f G', $byte / 1073741824);
    }
    elsif ($byte >= 104857600) {
        return sprintf ('%.0f M', $byte / 1048576);
    }
    elsif ($byte >= 10485760) {
        return sprintf ('%.1f M', $byte / 1048576);
    }
    elsif ($byte >= 1048576) {
        return sprintf ('%.2f M', $byte / 1048576);
    }
    elsif ($byte >= 102400) {
        return sprintf ('%.0f k', $byte / 1024);
    }
    elsif ($byte >= 10240) {
        return sprintf ('%.1f k', $byte / 1024);
    }
    elsif ($byte >= 1024) {
        return sprintf ('%.2f k', $byte / 1024);
    }
    elsif ($byte >= 100) {
        return sprintf ('%.0f', $byte);
    }
    
    return $byte . ' ';
}


=head2 size($dig)
    
Красивое отображение с округлением до порядка по базе 1000. Например:

    my $size = 1000*100;
    
    print Clib::Num::size($size);
    
    # Будет напечатано: 100 k

=cut

sub size {
    my $size = shift;
    
    return $size if !$size || ($size !~ /^\d+(\.\d+)?$/);
    
    $size = sprintf('%0.2f', $size) if $1;
    
       if ($size >= 990000000000) {
        return sprintf ('%0.2f T', $size / 1000000000000);
    }
    elsif ($size >= 100000000000) {
        return sprintf ('%0.0f G', $size / 1000000000);
    }
    elsif ($size >= 10000000000) {
        return sprintf ('%0.1f G', $size / 1000000000);
    }
    elsif ($size >= 990000000) {
        return sprintf ('%0.2f G', $size / 1000000000);
    }
    elsif ($size >= 100000000) {
        return sprintf ('%0.0f M', $size / 1000000);
    }
    elsif ($size >= 10000000) {
        return sprintf ('%0.1f M', $size / 1000000);
    }
    elsif ($size >= 990000) {
        return sprintf ('%0.2f M', $size / 1000000);
    }
    elsif ($size >= 100000) {
        return sprintf ('%0.0f k', $size / 1000);
    }
    elsif ($size >= 10000) {
        return sprintf ('%0.1f k', $size / 1000);
    }
    elsif ($size >= 990) {
        return sprintf ('%0.2f k', $size / 1000);
    }
    elsif ($size >= 100) {
        return sprintf ('%0.0f ', $size);
    }
    return $size . ' ';
}


=head2 summ($dig)
    
Сумма в русском стандарте - тысячи разделены пробелами, десятые - запятой.

    my $summ = 1000*150 + 0.1;
    
    print Clib::Num::summ($size);
    
    # Будет напечатано: 100 000,1

=cut

sub summ {
    my $summ = shift;
    return if !defined($summ);
    return $summ if $summ !~ /^\d([\d ]*\d)?([\,\.]\d+)?$/;
    
    $summ =~ s/ +//g; # сначала приводим к машинному виду
    $summ =~ s/,/./;
    
    my $s = '';
    # десятые
    $s = ",$2" if $summ =~ s/([\,\.](\d+))$//;
    
    my @t = (); # обрабатываем все тысячи
    while ($summ =~ /(\d\d\d)$/) {
        unshift @t, $1;
        $summ =~ s/(\d\d\d)$//;
    }
    unshift(@t, $summ) if $summ ne '';
    
    # Соединяем все в одну строчку
    return join(' ', @t).$s;
}


=head2 csv($dig)
    
Преобразует дробные числа в csv-формат, там вместо точек - запятые. Заменяет "." на ","

=cut

sub csv {
    my $s = shift;
    
    return '' if !defined($s);
    
    if ($s =~ /^\d+$/) {
        return $s;
    }
    elsif ($s =~ /^(-?\d+)[.,](\d+)$/) {
        return $1.','.$2;
    }
    
    $s =~ s/\"/\\\"/g;
    return '"'.$s.'"';
}

1;
