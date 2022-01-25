# NAME

Clib::strict - сокращённый вариант записи `use strict; use warnings;`

# SYNOPSIS

    # Чтобы не писать каждый раз код:

    # use strict;
    # use warnings;
    
    use Clib::strict;

# DESCRIPTION

Подключение этого модуля позволяет объединить написание привычного варианта в начале каждого модуля:

    use strict;
    use warnings;

заменив это одной строкой:

    use Clib::strict;

# SEE ALSO

- [strict](https://metacpan.org/pod/strict) - Perl pragma to restrict unsafe constructs
- [warnings](https://metacpan.org/pod/warnings) - Perl pragma to control optional warnings
- [Clib::strict8](https://metacpan.org/pod/Clib%3A%3Astrict8) - Аналогичный модуль, но ещё прибавляется `use utf8;`
