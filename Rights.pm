package Clib::Rights;

use strict;


=pod

=encoding UTF-8

=head1 NAME

Clib::Rights - Работа с правами доступа, закодированными в строке

=head1 SYNOPSIS
    
    use Clib::Rights;
    
    my $rnum = 1;
    my $rights = '';
    $rights = Clib::Rights::set($rights, $rnum, 'e');
    
    if (Clib::Rights::exists($rights, $rnum)) {
        print 'rights num='.$rnum;
        print ' is allow: '.Clib::Rights::val($rights, $rnum);
    }

=head1 DESCRIPTION

В строке $rights в каждом символе можно зашифровать определённое разрешение.
Данный модуль позволяет работать с этими разрешениями, устанавливая или получая текущее значение.

У каждого разрешения есть свой номер от 0 и ограничивается только длиной используемой строки.
А варианты значений для каждого разрешения устанавливаются программой, в котороый используется данный модуль.

Константы и функции этого модуля не импортируются в namespace модуля, в котором мы работаем.

Поэтому вызов требует указания имени модуля:

    Clib::Rights::val(...);

=head1 Константы

Есть стандартные значения разрешений.

=head2 DENY

Означает отсутствие разрешения с данным номером

=cut

use constant DENY   => '-';

=head2 GROUP

Говорит о необходимости обратиться к правам группы

=cut

use constant GROUP  => 'g';


=head1 Функции

=head2 val($rstr, $rnum)

Возвращает значение разрешения в строке $rstr с номером $rnum.

Фактически - возвращает символ в позиции $rnum.

=cut

sub val($$) {
    my $s = shift();
    my $num = shift();
    return if !defined($num);
    # $num содержит число-номер отдельного разрешения
    return substr($s, $num, 1);
}


=head2 chk($rstr, $rnum, $rval[, $rval2, ...])

Возвращает true, если значение разрешения с номером $rnum равно любому
из вариантов $rval, указанному в аргументах

=cut

sub chk {
    my $s = shift();
    my $num = shift();
    
    my $val = val($s, $num);
    $val = '' if !defined($val);
    
    foreach my $chk (@_) {
        return 1 if $val eq $chk;
    }
    
    return 0;
}


=head2 exists($rstr, $rnum)

Возвращает true, если есть любое значение разрешения с номером $rnum.
Значения DENY и GROUP не являются положительными (вернёт false).

=cut

sub exists($$) {
    my $val = val(shift(), shift());
    return if !defined($val) || ($val eq '');
    return ($val ne DENY) && ($val ne GROUP) ? 1 : 0;
}


=head2 combine($ruser, $rgroup[, $def_is_grp])

Комбинирует две строки с зашифрованными правами:

=over 4

=item *

$ruser - права пользователя, в них могут встречаться значения GROUP,
они будут заменены на права группы с тем же $rnum

=item *

$rgroup - права группы, значения GROUP будут трактованы как DENY

=back

Строка прав пользователя может быть короче строки прав группы.
Если указан true-флаг $def_is_grp, то отсутствующие значения в $ruser
будут приравнены к GROUP (как у группы).

=cut

sub combine {
    my $rusr = shift();
    my $rgrp = shift();
    my $def_is_grp = shift();
    
    $rusr .= GROUP while $def_is_grp && (length($rusr) < length($rgrp));
    my $len = length $rusr;
    
    for (my $i = 0; $i < $len; $i++) {
        my $v = substr $rusr, $i, 1;
        next if $v ne GROUP;
        
        my $g = substr $rgrp, $i, 1;
        $g = DENY if !defined($g) || ($g eq '');
        substr($rusr, $i, 1) = $g;
    }
    
    return $rusr;
}


=head2 set($rstr, $rnum, $rval[, $def_is_grp])

Возвращает модифицированную строку прав $rstr, где значение разрешения $rnum
установлено в $rval.

Не модифицирует переменную $rstr, переданную в аргументах.

Длина $rval должна быть равна 1 символу.

Строка $rstr может быть короче, чем номер разрешения $rnum. Если установлен
флаг $def_is_grp, то недостающие права будут установлены в GROUP (как у группы).

=cut

sub set {
    my $s = shift();
    my $num = shift();
    return $s if !defined($num);
    my $val = shift();
    my $def_is_grp = shift();
    
    while (length($s) <= $num) {
        $s .= $def_is_grp ? GROUP : DENY;
    }
    
    if (!defined($val) || !length($val) || (ord($val) < 32)) {
        $val = $def_is_grp ? GROUP : DENY;
    }
    $val = substr($val, 0, 1) if length($val) > 1;
    
    substr($s, $num, 1) = $val;
    
    return $s;
}


=head2 uset($rstr, $rnum, $rval)

Возвращает модифицированную строку прав $rstr для прав пользователя.

Эквивалентно вызову функции set() с флагом $def_is_grp=true

=cut

sub uset($$$) {
    return set(shift(), shift(), shift(), 1);
}


=head2 gset($rstr, $rnum, $rval)

Возвращает модифицированную строку прав $rstr для прав группы.

Эквивалентно вызову функции set() без флага $def_is_grp

=cut

sub gset($$$) {
    return set(shift(), shift(), shift(), 0);
}

#==========================================================
#================================================== End ===
#==========================================================
1;
