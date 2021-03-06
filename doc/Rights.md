# NAME

Clib::Rights - Работа с правами доступа, закодированными в строке

# SYNOPSIS

    use Clib::Rights;
    
    my $rnum = 1;
    my $rights = '';
    $rights = Clib::Rights::set($rights, $rnum, 'e');
    
    if (Clib::Rights::exists($rights, $rnum)) {
        print 'rights num='.$rnum;
        print ' is allow: '.Clib::Rights::val($rights, $rnum);
    }

# DESCRIPTION

В строке $rights в каждом символе можно зашифровать определённое разрешение.
Данный модуль позволяет работать с этими разрешениями, устанавливая или получая текущее значение.

У каждого разрешения есть свой номер от 0 и ограничивается только длиной используемой строки.
А варианты значений для каждого разрешения устанавливаются программой, в котороый используется данный модуль.

Константы и функции этого модуля не импортируются в namespace модуля, в котором мы работаем.

Поэтому вызов требует указания имени модуля:

    Clib::Rights::val(...);

# Константы

Есть стандартные значения разрешений.

## DENY

Означает отсутствие разрешения с данным номером

## GROUP

Говорит о необходимости обратиться к правам группы

# Функции

## val($rstr, $rnum)

Возвращает значение разрешения в строке $rstr с номером $rnum.

Фактически - возвращает символ в позиции $rnum.

## chk($rstr, $rnum, $rval\[, $rval2, ...\])

Возвращает true, если значение разрешения с номером $rnum равно любому
из вариантов $rval, указанному в аргументах

## exists($rstr, $rnum)

Возвращает true, если есть любое значение разрешения с номером $rnum.
Значения DENY и GROUP не являются положительными (вернёт false).

## combine($ruser, $rgroup\[, $def\_is\_grp\])

Комбинирует две строки с зашифрованными правами:

- $ruser - права пользователя, в них могут встречаться значения GROUP,
они будут заменены на права группы с тем же $rnum
- $rgroup - права группы, значения GROUP будут трактованы как DENY

Строка прав пользователя может быть короче строки прав группы.
Если указан true-флаг $def\_is\_grp, то отсутствующие значения в $ruser
будут приравнены к GROUP (как у группы).

## set($rstr, $rnum, $rval\[, $def\_is\_grp\])

Возвращает модифицированную строку прав $rstr, где значение разрешения $rnum
установлено в $rval.

Не модифицирует переменную $rstr, переданную в аргументах.

Длина $rval должна быть равна 1 символу.

Строка $rstr может быть короче, чем номер разрешения $rnum. Если установлен
флаг $def\_is\_grp, то недостающие права будут установлены в GROUP (как у группы).

## uset($rstr, $rnum, $rval)

Возвращает модифицированную строку прав $rstr для прав пользователя.

Эквивалентно вызову функции set() с флагом $def\_is\_grp=true

## gset($rstr, $rnum, $rval)

Возвращает модифицированную строку прав $rstr для прав группы.

Эквивалентно вызову функции set() без флага $def\_is\_grp
