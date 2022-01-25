# NAME

Clib::DT - Быстрые преобразования формата даты/времени

# SYNOPSIS

    use Clib::DT;
    
    print Clib::DT::date(time());

# Функции

Функции этого модуля не импортируются в namespace модуля, в котором мы работаем.

Поэтому вызов требует указания имени модуля:

    Clib::DT::date(...);

## date($dt)

Красивое отображение в формате: Д.ММ.ГГГГ

На входе может быть:

- Дата-время в MySQL-формате:

        ГГГГ-ММ-ДД  ч:мм:cc

- UTC-время в UNIX-формате. Например, возвращаемое стандартной Perl-функцией `time()`.

## datetime($dt)

Красивое отображение в формате: Д.ММ.ГГГГ ч:мм

На входе может быть:

- Дата-время в MySQL-формате:

        ГГГГ-ММ-ДД  ч:мм:cc

- UTC-время в UNIX-формате. Например, возвращаемое стандартной Perl-функцией `time()`.

## time($dt)

Выдёргивает из строки, которая пришла на вход, время из конца строки. Может быть использовано MySQL-дата-время.

Нормирует до вида: ч:мм

## compare($dt1, $dt2)

Сравнивает две даты-время в MySQL-формате. Используется при сортировке.

## date\_compare($dt1, $dt2)

Сравнивает только даты в MySQL-формате. Используется при сортировке.

Если в исходных данных присутствует время, оно игнорируется

## now()

Возвращает текущее дата-время в MySQL-формате.

## fromtime($time)

Преобразует из UNIX-time в MySQL-формат.

## totime($dt)

Преобразует из MySQL-формата в UNIX-time.

## daybeg($time\[, $days\])

Возвращает начало дня в UNIX-time-формате.

На входе может быть:

- Дата-время в MySQL-формате:

        ГГГГ-ММ-ДД  ч:мм:cc

- UTC-время в UNIX-формате. Например, возвращаемое стандартной Perl-функцией `time()`.

Если указан параметр `$days`, то это смещает время вперёд на нужное количество дней

## dayend($time\[, $days\])

Аналогично функции `daybeg($time[, $days])`, но возвращает время окончания текущего дня в UNIX-time-формате.

## sec2time($sec)

Преобразует количество секунд в отображение времени: ч:мм:сс

Если полных часов получилось больше 23, то в начале дописывается Xd - количество дней.

Например:

    5d 15:45:11

## mon2days($year, $mon)

Определяет количество дней в определённом месяце определённого года.