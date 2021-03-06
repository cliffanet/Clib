# NAME

Clib::Log - Обеспечивает логирование в файл и/или в консоль

# SYNOPSIS

    use Clib::Log;
    
    log('text message');
    debug('debug message');

В логах будет текст:

    24/12/21, 04:03:07: text message
    24/12/21, 04:03:08: debug message

# Типовое подключение

Структура файлов:

В файле `const.conf`:

    logPath => "/var/log/myproject",
    log_myproject => {
        log     => '$logPath/messages.log',
        debug   => 'log',
        error   => ['$logPath/error.log', 'log'],
    },

Для скрипта `script`:

    use Clib::Proc qw|script1 lib|;
    use Clib::Const ':utf8';
    use Clib::Log 'log_myproject';

# DESCRIPTION

Формирует интерфейс для записи логов в файл(ы). В указанном примере сообщения, будут 
направлены в файлы в зависимости от типа сообщения:

- `log(...)` - в файл "/var/log/myproject/messages.log";
- `debug(...)` - туда же, куда пишет `log(...)`: т.е. в файл "/var/log/myproject/messages.log";
- `error(...)` - в файл "/var/log/myproject/error.log",
и продублирует туда же, куда пишет `log(...)`:
т.е. в файл "/var/log/myproject/messages.log";

# Синтаксис вызова функций

Эквивалентен вызову функции `sprintf(...)`:

    log('Hello, %s!', $name);

# Опции подключения

Cтандартное подключение модуля:

    use Clib::Log;

Если подключен Clib::Const, путь для файлов логов будет взят из хеша `log`, например:

    log => {
        log     => '$logPath/messages.log',
        debug   => 'log',
        error   => ['$logPath/error.log', 'log'],
    },

Здесь мы определили путь для функции `log(...)`. Для функции `debug(...)` велено использовать тот же путь,
что и для `log(...)`. А для `error(...)` указан вариант, когда мы одной строчкой пишем в два разных файла.

## Формат "назначения"

В качестве пути, куда писать логи, можно указать:

- Имя файла
- Перенаправление - если в качестве "назначения" указано: log, error и т.л., то путь к файлу назначения будет взят оттуда.
- "-" (минус) - писать логи только в консоль, в файл логирования не будет.

## Опции, доступные только в use-прагме

- `:local` - указывает, что любые настройки подключения `Clib::Log`, указанные при подключении в нашем
текущем рабочем модуле считать локальными. Без этого флага любая опция импорта модуля будет влиять глобально
на весь запущенный процесс.
- `:pkg-prefix` - все функции записи в лог, используемые в нашем текущем рабочем модуле, где мы подключаем `Clib::Log`,
будут вписывать между временем и строкой в качестве префикса имя нашеего модуля:

        package MyPackage;
        
        use Clib::Log ':pkg-prefix';

        log('text message');

    В логах будет текст:

        24/12/21, 04:03:07: MyPackage > text message
        

- `pkg-prefix=строка` - все функции записи в лог, используемые в нашем текущем рабочем модуле, где мы подключаем `Clib::Log`,
будут вписывать между временем и строкой в качестве префикса - любую нужную нам строчку:

        use Clib::Log 'pkg-prefix=Test';

        log('text message');

    В логах будет текст:

        24/12/21, 04:03:07: Test > text message
        

## Опции, доступные как use-прагме, так и через const для каждой функции

Этот пример установит опцию `noconsole` для всех функций `Clib::Log`:

    use Clib::Log 'noconsole';

А так через функционал `Clib::Const` можно указать эту опцию только для функции `debug(...)`. В файле const.conf:

    log => {
        log     => '$logPath/messages.log',
        debug   => 'log',
        noconsole => ['debug']
    },

- `disable` - отключает логирование полностью.
- `die` - вызывает `die` с указанным текстом.
- `dump` - в качестве аргументов функции следует передавать переменные, которые с помощью Data::Dumper
будут парситься и отображать своё содержимое в логах.
- `null` - функция должна возвращать пустой список.
Без этой опции функция возвращает переданную ей строчку, собранную с аргументами применением `sprintf(...)`
- `prebuffer` - Функции с этой опцией не будут ничего никуда выводить до тех пор, пока любая из других функций
логирования без этой опции не попробует что-то вывести. При этом будут напечатаны все строки, которые должны были вывестись
с этой опцией.

    Например, мы с помощью `debug(...)` хотим всегда обозначать начало выполнение скрипта. Но не хотим, чтобы эта строчка
    писалась в логи, если скрипт выполнился без ошибок. Делаем для `debug(...)` опцию `prebuffer`:

        log => {
            log     => '$logPath/messages.log',
            debug   => 'log',
            error   => 'log',
            prebuffer => ['debug']
        },

    В коде:

        debug('Script begin');
        open(my $fh, 'text.txt') || error('Can\'t open: %s', $!);

    Всякий раз, когда мы запускаем скрипт, и файл 'text.txt' открывается успешно, в логи не будет ничего выводится.
    Но если при открытии произойдёт ошибка, то будет выведено две строчки:

        24/12/21, 04:03:07: Script begin
        24/12/21, 04:03:08: Can't open: No such file or directory
        

- `noconsole` - не будет выводить логи в консоль. Без этого флага любая функция, если для неё указан вывод в файл,
а скрипт запущен в консоли, то лог-строка будет выведена и в файл и в консоль. Этот флаг отключает вывод в консоль.

# Дополнительные префиксы

Функция `log_prefix(...)` добавит дополнительный префикс в лог-строчки при необходимости.

## `log_prefix(...)` в void-контексте

Префикс будет добавлен насовсем:

    log('Message 1');
    log_prefix('User test');
    log('Message 2');

Будет выведено:

    24/12/21, 04:03:07: Message 1
    24/12/21, 04:03:08: User test > Message 2
    

## `log_prefix(...)` в scalar-контексте

Удобно, когда нам надо ограничить работу префикса областью видимости:

        log('Message 1');
        {
            my $log = log_prefix('User test');
            log('Message 2');
        }
        log('Message 3');

    Будет выведено:

    24/12/21, 04:03:07: Message 1
    24/12/21, 04:03:08: User test > Message 2
    24/12/21, 04:03:09: Message 3
    
