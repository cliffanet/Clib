package Clib::Hash;

use strict;
use warnings;


=pod

=encoding UTF-8

=head1 NAME

Clib::Hash - Хеш-класс, позволяющих сохранять порядок заносимых в него ключей

=head1 SYNOPSIS
    
    use Clib::DT;
    
    my $h = Clib::Hash->byarray(
                key1 => 'value1', 
                key2 => 'value2'
            );
    
    my $h = Clib::Hash->byref(
                {
                    key1 => 'value1', 
                    key2 => 'value2',
                    ordered_by_keyname_1 => 'value3',
                    ordered_by_keyname_2 => 'value4',
                },
                qw/key1 key2/
            );

=cut


sub byarray {
    shift() if $_[0] && (($_[0] eq __PACKAGE__) || (ref($_[0]) eq __PACKAGE__));
    
    my %h;
    tie %h, 'Clib::Hash', @_;
    
    return \%h;
}

sub byref {
    shift() if $_[0] && (($_[0] eq __PACKAGE__) || (ref($_[0]) eq __PACKAGE__));
    
    $_[0] || return $_[0];
    my $h = { %{ shift() } };
    
    my %h;
    tie %h, 'Clib::Hash', 
        (map { 
            exists($h->{$_}) ?
                ($_ => delete($h->{$_})) :
                ()
        } @_),
        (map { ($_ => $h->{$_}) } sort keys %$h);
    
    return \%h;
}

sub TIEHASH {
    my($c) = shift;
    my($s) = [];
    CLEAR($s);

    bless $s, $c;

    $s->Push(@_) if @_;

    return $s;
}
 
#sub DESTROY {}           # costly if there's nothing to do
 
sub FETCH {
    my($s, $k) = (shift, shift);
    return exists( $s->[0]{$k} ) ? $s->[2][ $s->[0]{$k} ] : undef;
}
 
sub STORE {
    my($s, $k, $v) = (shift, shift, shift);
    
    if (exists $s->[0]{$k}) {
        my($i) = $s->[0]{$k};
        $s->[1][$i] = $k;
        $s->[2][$i] = $v;
        $s->[0]{$k} = $i;
    }
    else {
        push(@{$s->[1]}, $k);
        push(@{$s->[2]}, $v);
        $s->[0]{$k} = $#{$s->[1]};
    }
}
 
sub DELETE {
    my($s, $k) = (shift, shift);

    if (exists $s->[0]{$k}) {
        my($i) = $s->[0]{$k};
        for ($i+1..$#{$s->[1]}) {    # reset higher elt indexes
            $s->[0]{ $s->[1][$_] }--;    # timeconsuming, is there is better way?
        }
        if ( $i == $s->[3]-1 ) {
            $s->[3]--;
        }
        delete $s->[0]{$k};
        splice @{$s->[1]}, $i, 1;
        return (splice(@{$s->[2]}, $i, 1))[0];
    }
    return undef;
}
 
sub EXISTS {
    exists $_[0]->[0]{ $_[1] };
}
 
sub FIRSTKEY {
    $_[0][3] = 0;
    &NEXTKEY;
}
 
sub NEXTKEY {
    return $_[0][1][ $_[0][3]++ ] if ($_[0][3] <= $#{ $_[0][1] } );
    return undef;
}

sub CLEAR {
    my $s = shift;
    $s->[0] = {};   # hashkey index
    $s->[1] = [];   # array of keys
    $s->[2] = [];   # array of data
    $s->[3] = 0;    # iter count
    return;
}
 

#
# add pairs to end of indexed hash
# note that if a supplied key exists, it will not be reordered
#
sub Push {
    my($s) = shift;
    while (@_) {
        $s->STORE(shift, shift);
    }
    return scalar(@{$s->[1]});
}

sub ReorderTop {
    my $s = shift;
    
    my %n = %{ $s->[0] };
    my @keys = (
        (grep { defined(delete $n{$_}) } @_),
        (sort { $n{$a} <=> $n{$b} } keys %n)
    );
    $s->[1] = [ @keys ];
    my $n = $s->[0];
    my $d = $s->[2];
    $s->[2] = [ map { $d->[ $n->{$_} ] } @keys ];
    $n = 0;
    $s->[0] = { map { ($_ => $n++) } @keys };
    
    return \@keys;
}

sub ReorderBottom {
    my $s = shift;
    
    my %n = %{ $s->[0] };
    my @k = grep { defined(delete $n{$_}) } @_;
    my @keys = (
        (sort { $n{$a} <=> $n{$b} } keys %n),
        @k
    );
    $s->[1] = [ @keys ];
    my $n = $s->[0];
    my $d = $s->[2];
    $s->[2] = [ map { $d->[ $n->{$_} ] } @keys ];
    $n = 0;
    $s->[0] = { map { ($_ => $n++) } @keys };
    
    return \@keys;
}


1;
