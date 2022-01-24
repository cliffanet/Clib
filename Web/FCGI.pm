package Clib::Web::FCGI;

use strict;
use warnings;

use FCGI;
use FCGI::ProcManager;

use Clib::Web::CGI;


=pod

=encoding UTF-8

=head1 NAME

Clib::Web::CGI - Унифицированный FCGI-интерфейс.

=head1 SYNOPSIS
    
    use Clib::Web::FCGI;

    Clib::Web::FCGI->loop(
            procname    => 'fcgi-test-main',
            bind        => '0.0.0.0:9001',
            run_count   => 100,
            worker_count=> 5,
        );

    sub web_init {
        # Процедуры инициализации
    }

    sub web_request {
        return
            '<html><body>Hello, World!</body></html>',
            200,
            'Content-type' => 'text/html; charset=utf-8';
    }

=head1 Вызываемые функции скрипта

=head2 web_init()

Будет вызвана однократно в самом начале выполнения C<Clib::Web::FCGI->loop()>.

=head2 web_request()

Будет вызвана при http-запросе. Вернуть эта функция должна список:

=over 4

=item 1

Скаляр или ссылка на функцию - возвращаемый контент.

=item 2

HTTP-статус - если ничего не указано, статус будет = 200.

=item 3

HTTP-заголовки

=back

=cut

sub event {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    my $method = shift;
    $method || return;
    
    my $n = 0;
    my $callpkg = caller($n);
    $callpkg = caller(++$n) while $callpkg eq __PACKAGE__;
    $callpkg || return;
    $method = "${callpkg}::web_$method";
    
    no strict 'refs';
    
    exists(&$method) || return;
    
    return &$method(@_);
}

sub init {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    my %cfg = @_;
    
    $cfg{bind}          ||= "127.0.0.1:9000";
    $cfg{listen_count}  ||= 5;
    $cfg{worker_count}  ||= 5;
    $cfg{run_count}     ||= 1000;
    $cfg{procname}      ||= $cfg{proc}||$cfg{name};
    
    my %f = (run_count => $cfg{run_count});
    $f{sock} = FCGI::OpenSocket($cfg{bind}, $cfg{listen_count});
    $f{fcgi} = FCGI::Request(\*STDIN, \*STDOUT, \*STDERR, \%ENV, $f{sock});
    $f{pm}   = FCGI::ProcManager->new({
            n_processes => $cfg{worker_count},
            $cfg{procname} ? (pm_title    => $cfg{procname}) : (),
        });
    
    # Запуск обработчиков и распараллеливание
    # будет запущено указанное количество обработчиков
    $f{pm}->pm_manage();
    
    event('init');
    
    return %f;
}

sub request {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    my $fcgi = shift;
    
    #if ($self->{_is_running}) {
    #    # Проверка, что предыдущее выполнение не вылетело на середине
    #    $self->error("MP2 CLEAR ERROR: prev running not cleared");
    #    my %env1 = %ENV;
    #    $self->clear();
    #    %ENV = %env1;
    #}
    #$self->{_is_running} = 1;
    $ENV{SCRIPT_NAME} ||= '';
    $ENV{PATH_INFO} = $ENV{DOCUMENT_URI} || '' if !exists($ENV{PATH_INFO});
    if (!$ENV{PATH_INFO} && $ENV{DOCUMENT_URI}) {
        $ENV{PATH_INFO} = $ENV{DOCUMENT_URI};
        $ENV{PATH_INFO} =~ s/\?.*$//;
    }
    
    $ENV{PATH_INFO} ||= '/';
    
    my ($body, $status, @hdr) = event('request', $ENV{PATH_INFO});
    
    my %hdr = @hdr;
    if (!$hdr{'Content-type'}) {
        unshift @hdr, 'Content-type' => 'text/html';
    }
    
    if ($status) {
        my ($code, $txt) = split / /, $status, 2;
        
        if (($code > 1) && ($code != 200)) {
            unshift @hdr, Status => $status;
        }
        else {
            undef $status;
        }
    }
    
    if ($hdr{Location}) {
        undef $body;
    }
    
    while (@hdr > 1) {
        my $hdr = shift @hdr;
        my $val = shift @hdr;
        
        next if $hdr !~ /^[A-Z][a-zA-Z]*([\- ][a-zA-Z]+)*$/;
        
        print sprintf('%s: %s', $hdr, $val)."\n";
    }
    
    print "\n";
    
    defined($body) || return;
    
    if (ref($body) eq 'CODE') {
        $body = $body->(sub { print @_; $fcgi->Flush(); });
    }
    
    if (ref($body) eq 'SCALAR') {
        no warnings;
        print $$body;
    }
    else {
        no warnings;
        print $body;
    }
    
    ## Очистка переменных для следующего запроса
    #$self->clear();
    #$self->{_is_running} = 0;
    
    return 1;
}

sub loop {
    shift() if $_[0] && ($_[0] eq __PACKAGE__);
    
    my %f = init(@_);
    
    # цикл
    my $count = 0;
    while($f{fcgi}->Accept() >= 0) {
        $f{pm}->pm_pre_dispatch();
        
        request($f{fcgi});
        
        $f{pm}->pm_post_dispatch();
        
        $f{fcgi}->Finish();
        
        event('clear');
        
        $count++;
        last
            if $f{run_count} && ($f{run_count} > 0) && ($count >= $f{run_count});
    }
    
    # Завершение
    FCGI::CloseSocket($f{socket});
}

1;
