# NAME

Clib::Web::CGI - Унифицированный CGI-интерфейс.

# SYNOPSIS

    use Clib::Web::CGI;

    Clib::Web::CGI->loop();

    sub web_init {
        # Процедуры инициализации
    }

    sub web_request {
        return
            '<html><body>Hello, World!</body></html>',
            200,
            'Content-type' => 'text/html; charset=utf-8';
    }

# Вызываемые функции скрипта

## web\_init()

Будет вызвана однократно в самом начале выполнения `Clib::Web::CGI-`loop()>.

## web\_request()

Будет вызвана при http-запросе. Вернуть эта функция должна список:

1. Скаляр или ссылка на функцию - возвращаемый контент.
2. HTTP-статус - если ничего не указано, статус будет = 200.
3. HTTP-заголовки

CGI-интерфейс нужен больше для отладки работы web-скрипта. А полноценно унификация проявляется в модуле [FCGI.pm](https://metacpan.org/pod/FCGI.pm)
