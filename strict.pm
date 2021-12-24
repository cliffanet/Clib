package Clib::strict;

use strict;
#use warnings;
 
sub import {
    # use warnings;
    #${^WARNING_BITS} ^= ${^WARNING_BITS} ^ "\x10\x01\x00\x00\x00\x50\x04\x00\x00\x00\x00\x00\x00\x55\x51\x55\x50\x01";
    ${^WARNING_BITS} ^= ${^WARNING_BITS} ^ "\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55";
    
    $^H |= 0x00000602; # use strict;
    
}
 
sub unimport {
    $^H &= ~0x00000602;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Clib::strict - сокращённый вариант записи C<use strict; use warnings;>

=head1 SYNOPSIS

    # Чтобы не писать каждый раз код:

    # use strict;
    # use warnings;
    
    use Clib::strict;

=head1 DESCRIPTION

Подключение этого модуля позволяет объединить написание привычного варианта в начале каждого модуля:

    use strict;
    use warnings;

заменив это одной строкой:

    use Clib::strict;

=head1 SEE ALSO

=over 4

=item *

L<strict> - Perl pragma to restrict unsafe constructs

=item *

L<warnings> - Perl pragma to control optional warnings

=item *

L<Clib::strict8> - Аналогичный модуль, но ещё прибавляется C<use utf8;>

=back

=cut
