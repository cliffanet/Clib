# NAME

Clib::Web::CGI - Унифицированный Fast-CGI-интерфейс.

# SYNOPSIS

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

# Вызываемые функции скрипта

## web\_init()

Будет вызвана однократно в самом начале выполнения `Clib::Web::FCGI-`loop()>.

## web\_request()

Будет вызвана при http-запросе. Вернуть эта функция должна список:

1. Скаляр или ссылка на функцию - возвращаемый контент.
2. HTTP-статус - если ничего не указано, статус будет = 200.
3. HTTP-заголовки
