# NAME

Clib::Proc - Модуль для удобной корректировки работы всего процесса выполнения perl-скрипта, где он подключен.

# SYNOPSIS

    use Clib::Proc qw|script1 lib|;
    
    Clib::Proc::daemon(
        pidfile => (c('pidPath')||'.').'/syncd.pid',
        procname => 'xdeya-syncd',
        no => c('syncd_nodaemon')
    ) || exit -1;

# Подключение модуля

Некоторые опции модуля указываются при его подключении, чтобы сработать ещё на стадии компиляции кода.

Но чтобы этот модуль можно было подключить прагмой `use` из рабочей директории проекта,
надо сделать symlink на него в стандартных директориях подключения модулей.
В дальнейшем все модули проекта можно уже размещать внутри директории `lib` проекта, опираясь
на параметр "корень проекта".

Сделать symlink можно двумя способами. Первый способ:

    ln -s /usr/local/bin/perl /usr/bin/perl
    ln -s /home/Clib /usr/local/lib/perl5/site_perl/Clib

Второй способ:

    mkdir /usr/local/lib/perl5/site_perl/Clib
    ln -s /home/Clib/Proc.pm /usr/local/lib/perl5/site_perl/Clib/Proc.pm

# Корень проекта

Т.к. изначально у perl-кода есть только рабочая директория (та, из которой был запущен скрипт), 
но нет понятия "корень проекта", то даный модуль помогает настроить этот параметр, на который
в последствии опираются:

- `lib` - папка с модулями, расположенная внутри проекта, без необходимости распологать эти модули
в стандартных директориях, используемых прагмой `use`, и при этом не будем зависеть от рабочей
директории, в которую ведёт путь `./`, включённый по умолчанию в список стандартных.
- модуль `Clib::Const` - которому необходимо искать, где искать файлы const.conf и redefine.conf,
расположенные внутри проекта.
- модуль `Clib::Log` - в случае, если путь к логам указан относительный, то он будет строиться
от корня проекта.
- модуль `Clib::DB::MySQL` - если подключена папка lib внутри проекта с модулями,
в ней будет искаться конфиг для подключения к БД.

# Опции подключения модуля

## scriptN

Определяет корень проекта относительно запущенного скрипта.
script0 - скрипт лежит в корне проекта, script1 - скрипт лежит в подпапке проекта, и т.д.

    # корень проекта
    #  `- скрипт
    #
    use Clib::Proc 'script0';
    
    # корень проекта
    #  |- bin
    #  |   `- скрипт
    #  |
    #  `- lib
    #
    use Clib::Proc 'script1';

## libN

Определяет корень проекта относительно модуля, из которого подключается Clib::Proc.
Это можут быть удобно там, где не используется исполняемый скрипт проекта, напримр для mod\_perl.

lib0 - модуль лежит в корне проекта, lib1 - модуль лежит в подпапке проекта, и т.д.

    # корень проекта
    #  `- MyModule.pm
    #
    package MyModule;
    use Clib::Proc 'lib0';
    
    # корень проекта
    #  `- lib
    #      `- MyModule.pm
    #
    package MyModule;
    use Clib::Proc 'lib1';

## root=&lt;dir>

Указание вручную, что считать корнем проекта

## lib

Добавляет в стандартные пути поиска модулей директорию lib в корне проекта.

Для работы этой опции обязательно должен быть указан корень проекта
с помощью опций: `scriptN`, `libN` или `root=...`

## const/constutf8=&lt;basepath>

Загрузить константы через Clib::Const.
При отсутствии basepath используется корень, если он определён.

    # корень проекта
    #  |- bin
    #  |   `- скрипт
    #  |
    #  `- const.conf
    #
    use Clib::Proc qw|script1 constutf8|;

Эквивалентно:

    use Clib::Proc qw|script1|;
    use Clib::Const ':utf8';

## pid=&lt;file>

Использовать pidfile. Если подгружен Clib:::Const,
возможно использование констант в формате $varname.

    use Clib::Proc qw|script1 pid=$pidPath/myproject.pid|;

При использовании pid-файла невозможно запустить второй такой же процесс,
пока выполняется запущенный ранее.

## strict

    use Clib::Proc qw|script1 strict|;

Эквивалентно

    use Clib::Proc qw|script1|;
    use strict;

## strict8

    use Clib::Proc qw|script1 strict8|;

Эквивалентно

    use Clib::Proc qw|script1|;
    use strict;
    use utf8;

# Импортируемые функции и переменные

При подключении `Clib::Proc` эти функции можно применять без префикса `Clib::Proc::`

## ROOT()

Возвращает путь к корню проекта, определённого опциями
подключения: `scriptN`, `libN` или `root=...`

## $pathRoot

Переменная, хранящая всё тот же путь к корню проекта.

## SCRIPTDIR()

Возвращает путь к директории, в которой лежит скрипт, если корень проекта
определен опцией подключения `scriptN`

## 

# fork-функционал

Пример:

    # Преподготовка для форка
    my $f = Clib::Proc->forkinit();
    $f->onterm(sub {
        my %p = @_;
        debug('Terminated [%d] %s', $p{pid}, $p{ip});
    });

    # Основной цикл приёма входящих соединений
    while ($sockSrv) {
        my $sock = $sockSrv->accept() || next;

        # форкаемся
        my $pid = $f->fork(sock => $sock) || return;
        if ($f->ischld()) {
            # клиентский процесс
            cli_recv($sock);
            last;
        }
    }

## Clib::Proc->forkinit()

Инициализирует fork-объект:

- В этом объекте в серверном процессе хранится список дочерних процессов.
- Создаёт обработчик SIG-CHLD, в котором доубиваются дочерние процессы,
закончившие свою работу.
- При уничтожении этого объекта будут завершены через SIG-TERM все дочерние процессы.

## fork(хеш-параметров)

Делает fork текущему процессу.

Для дочернего процесса содержимое этого fork-объекта обнуляется и ни на что больше не влияет.

Для основного процесса данные о дочернем сохраняются в списке.

`хеш-параметров` при вызове метода - это любой хеш, который сохранится в списке процессов
и будет передан в обработчик `onterm` при его завершении, а также будет доступен через
список дочерних процессов, получаемых методом `childs()`

## childs()

Возвращает хеш дочерних процессов, где:

- ключ - PID процесса
- значение - хеш с параметрами, переданными в методе `fork()` для создания этого дочернего процесса.

## chldcnt()

Возвращает количество дочерних процессов

## ischld()

Помогает определить, является ли текущий процесс дочерним или основным.

## onterm($hnd)

Устанавливает обработчик при завершении дочернего процесса.

$hnd - ссылка на функцию. В эту функцию в качестве аргументов будет передан хеш
с параметрами, переданными в методе `fork()` для создания этого дочернего процесса.

## termall()

Завершение всех дочерних процессов из основного процесса через SIG-TERM.
Этот метод вызывается автоматически при уничтожении объекта,
даже если это происходит при завершении основного процесса.

# Clib::Proc::daemon() - демонизация

Для текущего процесса выполняется отвязка от консоли.

Аргументы передаются в виде хеша:

- `pidfile` - ссылка на pid-файл, допустимо использовать $var, если подключен `Clib::Const`.
- `uid` - делает `setuid()` для процесса.
- `gid` - делает `setgid()` для процесса.
- `procname` - задаёт имя процессу.

При успехе всех процедур возвращает 1. Возвращает 0 при любой неудаче.

# Clib::Proc::sigint() - обработка завершения процесса

При передаче аргументов использует их как обработчики
завершения процесса по сигналам: `INT`, `TERM`, `QUIT`.

Возвращает полный список текущих обработчиков.

    Clib::Proc::sigint(sub {
        $sockSrv->close() if $sockSrv;
        undef $sockSrv;
    });

# Обращение к функциям скрипта через аргументы запуска

    use Clib::Proc qw|strict8 script1 lib param|;
    
    my @cmd = Clib::Proc::paramscript_cmdref();
    if (!@cmd || (grep { !$_ } @cmd)) {
        print "  Command list:\n";
        foreach my $cmd (Clib::Proc::paramscript_cmdall()) {
            my ($comment) = Clib::Proc::paramscript_cmdarg($cmd);
            $comment = $comment ? "\t: " . $comment : '';
            
            print "  - $cmd$comment\n";
        }
        exit -1;
    }
    
    foreach my $cmd (@cmd) {
        $cmd->();
    }
    
    sub start : Cmd('Starting all config options on system') {
        # меняет состояние всех влан на Init и настраивает
        
    }
    
    sub check : Cmd('Check all config options on system') {
        # check - это как обычный check по всем настройкам, без изменения текущего состояния
    }

## Clib::Proc::paramscript\_cmdref()

Возвращает список ссылок на функции с аттрибутом `Cmd`,
которые были перечислены в командной строке в виде аргументов.

    my @cmd = Clib::Proc::paramscript_cmdref();

    foreach my $cmd (@cmd) {
        $cmd->();
    }

## Clib::Proc::paramscript\_cmdall()

Возвращает список названий всех доступных функций скрипта с тегом `Cmd`

## Clib::Proc::paramscript\_cmdarg($cmd)

Возвращает список всех аргументов тега `Cmd` для функции с именем `$cmd`.