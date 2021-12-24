package Clib::DT;

use strict;
use warnings;

use Time::Local;


=pod

=encoding UTF-8

=head1 NAME

Clib::DT - Быстрые преобразования формата даты/времени

=head1 SYNOPSIS
    
    use Clib::DT;
    
    print Clib::DT::date(time());

=head1 Функции

Функции этого модуля не импортируются в namespace модуля, в котором мы работаем.

Поэтому вызов требует указания имени модуля:

    Clib::DT::date(...);

=cut

=head2 date($dt)
    
Красивое отображение в формате: Д.ММ.ГГГГ

На входе может быть:

=over 4

=item *

Дата-время в MySQL-формате:

    ГГГГ-ММ-ДД  ч:мм:cc

=item *

UTC-время в UNIX-формате. Например, возвращаемое стандартной Perl-функцией C<time()>.

=back

=cut

sub date {
    my ($dt) = @_;
    $dt ||= '';
    if ($dt =~ /^(\d{4})-(\d+)-(\d+)/) {
        return sprintf("%d.%02d.%s", $3, $2, $1);
    }
    elsif ($dt =~ /^\d{10,}$/) {
        my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($dt);
        $mon++;
        $year+=1900;
        return sprintf("%d.%02d.%s", $mday, $mon, $year);
    }
    $dt;
}


=head2 datetime($dt)
    
Красивое отображение в формате: Д.ММ.ГГГГ ч:мм

На входе может быть:

=over 4

=item *

Дата-время в MySQL-формате:

    ГГГГ-ММ-ДД  ч:мм:cc

=item *

UTC-время в UNIX-формате. Например, возвращаемое стандартной Perl-функцией C<time()>.

=back

=cut

sub datetime($dt) {
    my ($dt) = @_;
    $dt ||= '';
    if ($dt =~ /^(\d{4})-(\d+)-(\d+)\s+(\d+):(\d+)/) {
        return sprintf("%d.%02d.%s %d:%02d", $3, $2, $1, $4, $5);
    }
    elsif ($dt =~ /^\d{10,}$/) {
        my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($dt);
        $mon++;
        $year+=1900;
        return sprintf("%d.%02d.%s %d:%02d", $mday, $mon, $year, $hour, $min);
    }
    $dt;
}


=head2 time($dt)
    
Выдёргивает из строки, которая пришла на вход, время из конца строки. Может быть использовано MySQL-дата-время.

Нормирует до вида: ч:мм

=cut

sub time {
    my ($dt) = @_;
    $dt ||= '';
    my ($h, $m) = $dt =~ /(\d+):(\d+)(:\d+)?/ ? ($1, $2) : (0, 0);
    return $h > 23 ?
        sprintf('%dd %02d:%02d', int($h / 24), $h % 24, $m) :
        sprintf('%d:%02d', $h, $m);
}

my $dt_regexp = '^(\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$';


=head2 compare($dt1, $dt2)
    
Сравнивает две даты-время в MySQL-формате. Используется при сортировке.

=cut

sub compare {
    my ($dt1, $dt2) = @_;
    
    return unless $dt1 && ($dt1 =~ /$dt_regexp/o);
    $dt1 = sprintf("%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4||0, $5||0, $6||0);
    return unless $dt2 && ($dt2 =~ /$dt_regexp/o);
    $dt2 = sprintf("%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4||0, $5||0, $6||0);
    
    return $dt1 <=> $dt2;
}


=head2 date_compare($dt1, $dt2)
    
Сравнивает только даты в MySQL-формате. Используется при сортировке.

Если в исходных данных присутствует время, оно игнорируется

=cut

sub date_compare {
    my ($dt1, $dt2) = @_;
    
    return unless $dt1 && ($dt1 =~ /$dt_regexp/o);
    $dt1 = sprintf("%04d%02d%02d", $1, $2, $3);
    return unless $dt2 && ($dt2 =~ /$dt_regexp/o);
    $dt2 = sprintf("%04d%02d%02d", $1, $2, $3);
    
    return $dt1 <=> $dt2;
}


=head2 now()
    
Возвращает текущее дата-время в MySQL-формате.

=cut

sub now {
    my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(CORE::time());
    $mon++;
    $year+=1900;
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
}


=head2 fromtime($time)
    
Преобразует из UNIX-time в MySQL-формат.

=cut

sub fromtime {
    my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(shift);
    $mon++;
    $year+=1900;
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
}


=head2 totime($dt)
    
Преобразует из MySQL-формата в UNIX-time.

=cut

sub totime {
    my $dt = shift;
    $dt || return;
    return 0 if $dt =~ /^0000\-0+\-0+/;
    return
        $dt =~ /$dt_regexp/o ?
                timelocal($6||0, $5||0, $4||0, int($3)||1, (int($2)||1)-1, (int($1)||1900)-1900) :
        $dt =~ /^(\d{4})-(\d{1,2})-(\d{1,2})T(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?Z$/ ?
                timelocal($6||0, $5||0, $4||0, $3, $2-1, $1-1900) :
                0;
}


=head2 daybeg($time[, $days])
    
Возвращает начало дня в UNIX-time-формате.

На входе может быть:

=over 4

=item *

Дата-время в MySQL-формате:

    ГГГГ-ММ-ДД  ч:мм:cc

=item *

UTC-время в UNIX-формате. Например, возвращаемое стандартной Perl-функцией C<time()>.

=back

Если указан параметр C<$days>, то это смещает время вперёд на нужное количество дней

=cut

sub daybeg {
    # Начало суток даты $time + смещение $days
    my ($time, $days) = @_;
    
    $time || return;
    $time = totime($time) if $time =~ /$dt_regexp/o;
    
    $days ||= 0;
    my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time + ($days * 3600 * 24));
    
    return timelocal(0, 0, 0, $mday, $mon, $year);
}


=head2 dayend($time[, $days])
    
Аналогично функции C<daybeg($time[, $days])>, но возвращает время окончания текущего дня в UNIX-time-формате.

=cut

sub dayend {
    # Конец суток даты $time + смещение $days
    my ($time, $days) = @_;
    
    $time || return;
    $time = totime($time) if $time =~ /$dt_regexp/o;
    
    $days ||= 0;
    return daybeg($time, $days+1)-1;
}


=head2 sec2time($sec)
    
Преобразует количество секунд в отображение времени: ч:мм:сс

Если полных часов получилось больше 23, то в начале дописывается Xd - количество дней.

Например:

    5d 15:45:11

=cut

sub sec2time {
    my $sec = shift;
    
    my $str = '';
    if ($sec < 0) {
        $str = '-';
        $sec = -1 * $sec;
    }
    
    my $m = int($sec/60);
    $sec -= $m*60;
    
    my $h = int($m/60);
    $m -= $h*60;
    
    my $d = int($h/24);
    $h -= $d*24;
    
    $str .= sprintf("%dd ", $d) if $d > 0;
    $str .= sprintf("%d:%02d:%02d", $h, $m, $sec);
    
    return $str;
}


=head2 mon2days($year, $mon)
    
Определяет количество дней в определённом месяце определённого года.

=cut

sub mon2days {
    my ($year, $mon) = @_;
    
    if ($year >= 1900) {
        $mon--;
        $year-=1900;
    }
    
    $mon++;
    if ($mon >= 12) {
        $mon = 0;
        $year ++;
    }
    
    my $time = timelocal(0, 0, 0, 1, $mon, $year);
    
    my(undef, undef, undef, $mday) = localtime($time - 1);
    
    return $mday;
}

1;
