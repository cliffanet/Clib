package Clib::TimeCount;

use strict;
use warnings;

use Time::HiRes qw(gettimeofday tv_interval);
my $scriptTime;
BEGIN { $scriptTime = [gettimeofday]; }

my $runCount = 0;


=pod

=encoding UTF-8

=head1 NAME

Clib::TimeCount - Измерение времени работы скрипта с момента подключения этого модуля

=head1 SYNOPSIS
    
    use Clib::TimeCount;
    
    while (1) {
        Clib::TimeCount->run();
        
        # тут может быть какая-то длинная процедура
        
        my $time = Clib::TimeCount->interval();
    }

=cut

=head1 Функции

=head2 run()

Если это процесс обрабатывающий что-то в бесконечном цикле,
то запустив эту функцию в начале цикла в конце мы получим время выполнения итерации.

Если требуется просто замерить время работы скрипта от момента подключения этого модуля,
тогда эту функцию вызывать не надо.

=cut

sub run {
    if ($runCount) {
        $scriptTime = [gettimeofday];
    }
    $runCount ++;
    return $runCount;
}

=head2 info()

Возвращает списком текущие параметры

=over 4

=item *

Количество выполнений функции run()

=item *

Время от предыдущего запуска функции run() или от момента подключения этого модуля.

=back

=cut

sub info {
    return $runCount, tv_interval($scriptTime, [gettimeofday]);
}

=head2 count()

Возвращает количество выполнений функции run()

=cut

sub count { $runCount; }

=head2 interval()

Возвращает время от предыдущего запуска функции run()
или от момента подключения этого модуля, если запусков не было.

=cut

sub interval { tv_interval($scriptTime, [gettimeofday]); }

1;
