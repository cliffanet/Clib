package Clib::DB::MySQL::Srch;

use strict;
use warnings;


my %srch;

sub _srch_expr_uno {
    my ($name, $code1, $code2, $q, $f) = @_;
    
    return "`$name`-args: field"
        if (@_ != 5) ||!_is_field($f);
    my @where = ();
    push @where, "$code1`$f`$code2";
    
    return
        code => @where == 1 ?
                    $where[0] :
                    '('.join(' OR ', @where).')';
}

sub _srch_expr_pair {
    my ($name, $code1, $code2, $q, $f, $val) = @_;
    
    return "`$name`-args: field => value"
        if (@_ != 6) ||!_is_field($f);
    my @where = ();
    my @param = ();
    foreach my $v (ref($val) eq 'ARRAY' ? @$val : ($val)) {
        if (my $m = _is_srch($v)) {
            my %q = $srch{$m}->($q, @{ $v->{arg} });
            return err => $q{err} if $q{err};
            push @where, "`$f` $code1($q{code})$code2";
            push @param,  @{ $q{param}||[] };
        }
        elsif (!ref($v)) {
            push @where, "`$f` $code1?$code2";
            push @param, $v;
        }
        else {
            return err => "`$name` support only expression-value";
        }
    }
    
    return
        code => @where == 1 ?
                    $where[0] :
                    '('.join(' OR ', @where).')',
        @param ? (param => [ @param ]) : ();
}

sub _srch_expr_bool {
    my ($name, $join, $q) = (shift, shift, shift);
        
    my $n = 0;
    my @where = ();
    my @param = ();
    while (@_) {
        my $p = shift;
        $n++;
        my %q;
        
        if (my $m = _is_srch($p)) {
            %q = $srch{$m}->(\%q, @{ $p->{arg} });
        }
        elsif (_is_field($p)) {
            %q = $srch{eq}->(\%q, $p, shift);
        }
        else {
            $q{err} = 'unknown';
        }
        
        return (err => $q{err}) if $q{err};
        
        push(@where, $q{code}) if $q{code};
        push(@param, @{ $q{param} }) if $q{param};
    }
    
    @where || return err => "`$name` need minimum 1 expression";
    
    return
        code  => @where == 1 ?
                    $where[0] :
                    '('.join($join, @where).')',
        param => [@param];
}

%srch = (
    (
        map { my @p = @$_; ($_->[0] => sub { _srch_expr_uno(@p, @_) }) }
        (
            [null   => '',  ' IS NULL'],
            [notnull=> '',  ' IS NOT NULL'],
            [oldnow => '',  ' < NOW()'],
        )
    ),
    
    (
        map { my @p = @$_; ($_->[0] => sub { _srch_expr_pair(@p, @_) }) }
        (
            [eq     => '= ',    ''],
            [noteq  => '!= ',   ''],
            [like   => 'LIKE ', ''],
            [gt     => '> ',    ''],
            [ge     => '>= ',   ''],
            [lt     => '< ',    ''],
            [le     => '<= ',   ''],
            [oldest => '< DATE_SUB(NOW(), INTERVAL ', ' SECOND)'],
            [later  => '>= DATE_SUB(NOW(), INTERVAL ', ' SECOND)'],
            [password=>'= PASSWORD(',    ')'],
        )
    ),
    
    (
        map { my @p = @$_; ($_->[0] => sub { _srch_expr_bool(@p, @_) }) }
        (
            [or     => ' OR '],
            [and    => ' AND '],
        )
    ),
);


sub _is_srch {
    my $p = shift;
    return
            (ref($p) eq 'HASH') &&
            $p->{m} && $srch{ $p->{m} } &&
            (ref($p->{arg}) eq 'ARRAY') ?
        $p->{m} : '';
}

my %opt = (
    #'prefetch' => sub {
    #},
    
    order => sub {
        my $q = shift;
        return
            order => [
                map { s/^\s*\-\s*// ? $_ . ' DESC' : $_ } @_
            ];
    },
    group => sub {
        my $q = shift;
        return group => [ @_ ];
    },
    limit => sub {
        my $q = shift;
        return limit => [ @_ ];
    },
);
sub _is_opt {
    my $p = shift;
    return
            (ref($p) eq 'HASH') &&
            $p->{m} && $opt{ $p->{m} } &&
            (ref($p->{arg}) eq 'ARRAY') ?
        $p->{m} : '';
}

sub _is_field {
    my $p = shift;
    return !ref($p) && defined($p) && ($p =~ /^[a-zA-Z\_][a-zA-Z\_0-9\.]*$/);
}

sub parse {
    my ($db, $tbl, $t, @srch) = @_;
    
    my %q = (
        field => [],
        tbl => [],
        tblname => {},
    );
    $tbl = { name => $tbl, code => "`$t`" };
    push @{ $q{tbl} }, $tbl;
    $q{tblname}->{$tbl->{name}} = $tbl;
    $q{tblname}->{$t} = $tbl;
    push @{ $q{field} }, "`$t`.*";
    
    my $n = 0;
    my @where = ();
    my @param = ();
    my @order = ();
    my @group = ();
    my @limit = ();
    while (@srch) {
        my $p = shift @srch;
        $n++;
        my %q1;
        
        if (my $m = _is_srch($p)) {
            %q1 = $srch{$m}->(\%q, @{ $p->{arg} });
        }
        elsif ($m = _is_opt($p)) {
            %q1 = $opt{$m}->(\%q, @{ $p->{arg} });
        }
        elsif ((ref($p) eq 'HASH') && $p->{onpage} && ($p->{onpage} =~ /^\d+$/)) {
            $q{pager} = $p;
        }
        elsif (ref($p) eq 'CODE') {
            $q{hnd} = $p;
        }
        elsif (_is_field($p)) {
            %q1 = $srch{eq}->(\%q, $p, shift(@srch));
        }
        else {
            $q1{err} = 'unknown';
        }
        
        return (%q, err => $q1{err}) if $q1{err};
        
        push(@where, $q1{code}) if $q1{code};
        push(@param, @{ $q1{param} }) if $q1{param};
        push(@order, @{ $q1{order} }) if $q1{order};
        push(@group, @{ $q1{group} }) if $q1{group};
        push(@limit, map { int $_; } @{ $q1{limit} }) if $q1{limit};
    }
    
    return
        %q,
        where => join(' AND ', @where),
        order => join(', ', @order),
        group => join(', ', @group),
        limit => join(', ', @limit),
        param => [@param];
}

1;