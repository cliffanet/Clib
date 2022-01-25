# NAME

Clib::strict8 - сокращённый вариант записи use strict; use utf8;

# SYNOPSIS

    # Чтобы не писать каждый раз код:

    # use strict;
    # use warnings;
    # use utf8;
    
    use Clib::strict8;

# DESCRIPTION

Подключение этого модуля позволяет объединить написание привычного варианта в начале каждого модуля:

    use strict;
    use warnings;
    use utf8;

заменив это одной строкой:

    use Clib::strict8;

# SEE ALSO

- [strict](https://metacpan.org/pod/strict) - Perl pragma to restrict unsafe constructs
- [warnings](https://metacpan.org/pod/warnings) - Perl pragma to control optional warnings
- [utf8](https://metacpan.org/pod/utf8) - Perl pragma to enable/disable UTF-8 (or UTF-EBCDIC) in source code
- [Clib::strict](https://metacpan.org/pod/Clib%3A%3Astrict) - Аналогичный модуль, но без `use utf8;`
