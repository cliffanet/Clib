package Clib::DB::MySQL;

use strict;
use warnings;

use DBI;
use Clib::Log;
use Clib::DB::MySQL::Srch;

my $error;
sub err { $error }

sub logquery {
    my $db = shift() || return;
    my $str = shift() || return;
    
    $str = $db->{name} eq '' ?
        'MySQL > '.$str :
        sprintf('%s > %s', $db->{name}, $str);
    
    debug($str, @_);
}

sub logquery_disable {
    log_flag(debug => disable => 1);
}

sub logquery_enable {
    log_flag(debug => disable => 0);
}

sub logerror {
    my $db = shift() || return;
    my $str = shift() || return;
    
    $str = sprintf($str, @_) if @_;
    $error = $str;
    
    $str = $db->{name} eq '' ?
        'MySQL ERROR > '.$str :
        sprintf('%s ERROR > %s', $db->{name}, $str);
    
    error($str);
}

my %db = ();

sub import {
    my $pkg = shift;
    
    my $noimport = grep { $_ eq ':noimport' } @_;
    if ($noimport) {
        @_ = grep { $_ ne ':noimport' } @_;
        $noimport = ':noimport';
    }
    
    my ($cfg, $dbname) = @_;
    $cfg ||= 'DB';
    $dbname = $cfg unless defined $dbname;
    
    if (!$db{$dbname}) {
        my $db = init($cfg, $dbname);
        defined($db) || die $error;
    }
    
    $noimport || importer($dbname);
}

sub importer {
    my $dbname = shift;
    $dbname = '' unless defined $dbname;
    
    my $prefix = shift();
    $prefix = 'sql' unless defined $prefix;
    
    my $callpkg = caller(0);
    $callpkg = caller(1) if $callpkg eq __PACKAGE__;
    no strict 'refs';
    foreach my $n (qw/do srch func count max queryList get all add rep upd updf set del
                        connect disconnect ping
                        preFork mainFork chldFork/) {
        *{"${callpkg}::$prefix\u$n"} = sub {
            my $db = $db{$dbname};
            if (!$db) {
                $error = 'Unknown DB `.$dbname.` on sql-'.$n;
                return;
            }
            &{"_$n"}($db, @_);
        };
    }
    
    foreach my $n (qw/Eq NotEq Like Gt GE Lt LE Oldest Later OldNow Or And Null NotNull Password Order Group Limit/) {
        my $m = lc $n;
        *{"${callpkg}::$prefix$n"} = sub {
            return { m => $m, arg => [ @_ ] };
        };
    }
}

sub init {
    my $cfg = shift;
    
    my $db = { name => shift() || '', tbl => {} };
    
    if ($db{$db->{name}}) {
        logerror($db, 'Reinit DB `%s`, need close first', $db);
        return;
    }
    
    # читаем конфиг
    $cfg .= '.pm' if $cfg !~ /\.[a-zA-Z0-9]{1,4}^/;
    
    if ($INC{'Clib/Proc.pm'} && (my @lib = Clib::Proc::lib())) {
        foreach my $lib (@lib) {
            my $file = $lib . '/' . $cfg;
            next unless -f $file;
            $cfg = $file;
            last;
        }
    }
    
    my $fh;
    if (!open($fh, $cfg)) {
        logerror($db, 'Can\'t read file `%s`: %s', $cfg, $!);
        return;
    }
    
    local $/ = undef;
    my $code = <$fh>;
    close $fh;
    
    if (!$code) {
        logerror($db, 'File `%s` is empty', $cfg);
        return;
    }
    
    my %cfg = eval '('.$code.')';
    if ($@) {
        logerror($db, 'Can\'t read Mysql cfg-file \'%s\': %s', $cfg, $@);
        return;
    }
    
    # Список таблиц
    my %tbl;
    if (ref($cfg{tbl}) eq 'HASH') {
        %tbl = %{ $cfg{tbl} };
    }
    elsif (ref($cfg{tbl}) eq 'ARRAY') {
        %tbl = map { ($_ => undef) } @{ $cfg{tbl} };
    }
    else {
        %tbl = %cfg;
        delete($tbl{$_}) foreach qw/connect link/;
    }
    
    my $tbl = $db->{tbl};
    foreach my $key (keys %tbl) {
        my $t = $tbl{$key};
        $t ||= $key;
        $tbl->{$key} = $t;
    }
    
    # Линковка с другими таблицами
    # Пока не проработана
    #if (ref($cfg{link}) eq 'HASH') {
    #    $db->{link} = {
    #        map {
    #            my $link = {};
    #            my $l = $cfg{link}->{$_};
    #            if (ref($l) eq 'ARRAY') {
    #                if (@$l == 1) {         # link => [dst_tbl]
    #                    ($link->{dst_tbl}) = @$l;
    #                }
    #                elsif (@$l == 2) {      # link => [left/right, dst_tbl]
    #                    ($link->{type}, $link->{dst_tbl}) = @$l;
    #                }
    #                elsif (@$l == 3) {      # link => [loc_fld, dst_tbl, dst_fld]
    #                    ($link->{loc_fld}, $link->{dst_tbl}, $link->{dst_fld}) = @$l;
    #                }
    #                elsif (@$l >= 4) {      # link => [loc_fld, left/right, dst_tbl, dst_fld]
    #                    ($link->{loc_fld}, $link->{type}, $link->{dst_tbl}, $link->{dst_fld}) = @$l;
    #                }
    #            }
    #            elsif ($l) {                # link => dst_tbl
    #                $link->{dst_tbl} = $l;
    #            }
    #            ($_ => $l);
    #        }
    #        keys %{ $cfg{link} }
    #    }
    #}
    
    # Кодировка
    $db->{utf8} = 1 if $cfg{utf8};
    
    # Соединение
    $db->{args} = $cfg{args} if ref($cfg{args}) eq 'HASH';
    $db->{onconnect} = [ @{ $cfg{onconnect} } ] if ref($cfg{onconnect}) eq 'ARRAY';
    
    my $connect = $cfg{connect} || 'db';
    
    $connect = Clib::Const::get($connect) if !ref($connect) && $INC{'Clib/Const.pm'};
    
    # dbi
    if (!$connect) {
        logerror($db, 'Connect info not defined');
        return;
    }
    if (ref($connect) eq 'HASH') {
        my %conn = %$connect;
        my $socket = $conn{sock} ? ";mysql_socket=$conn{sock}" : '';
        $conn{dbase} ||= $conn{base} || $conn{name};
        $conn{pass} ||= $conn{passwd} || $conn{password};
        $conn{host} ||= '';
        $db->{dbi} = ["DBI:mysql:database=$conn{dbase};host=$conn{host}$socket", $conn{user}, $conn{pass}, $conn{args}];
        $db->{connectlog} = ($socket||$conn{host}).':'.$conn{dbase}.' by '.$conn{user};
        
        if ($connect->{onconnect}) {
            my @do = $connect->{onconnect};
            @do = @{ $do[0] } if $do[0] eq 'ARRAY';
            $db->{onconnect} = [ @do ] if @do;
        }
    }
    elsif (ref($connect) eq 'ARRAY') {
        $db->{dbi} = [ @$connect ];
        $db->{connectlog} = $db->{dbi}->[0].' by '.$db->{dbi}->[1];
    }
    else {
        logerror($db, 'Connect info unknown format');
        return;
    }
    
    # args (Рсширенные аргументы соединения)
    my $args = $db->{dbi}->[3] || $db->{args} || {};
    
    if (!exists($args->{mysql_auto_reconnect})) {
        # Если нет принудительного включения автореконнекта,
        # то принудительно его выключаем. С каких-то версий DBD::mysql он стал по умолчанию включенным
        $args = { %$args, mysql_auto_reconnect => 0 };
    }
    
    if (!exists($args->{RaiseError})) {
        $args = { %$args, RaiseError => 0 };
    }
    
    if (!exists($args->{PrintError})) {
        $args = { %$args, PrintError => 0 };
    }
    
    if ($db->{utf8}) {
        $args = { %$args, mysql_enable_utf8 => 1 };
        unshift @{ $db->{onconnect} ||= [] }, 'set names utf8';
    }
    
    $db->{dbi}->[3] = $args;
    
    $db{$db->{name}} = $db;
}

sub connect {
    # obj call
    shift if $_[0] && (($_[0] eq __PACKAGE__) || (ref($_[0]) eq __PACKAGE__));
    
    return _connect(@_) if @_;
    
    foreach (values %db) {
        _connect($_) || return;
    }
    
    keys %db;
}

sub _connect {
    my $db = shift() || return;
    return $db->{dbh} if $db->{dbh};
    
    eval {
        $db->{dbh} = DBI->connect(@{ $db->{dbi} });
    };
    if ($@) {
        logerror($db, 'DBI-Exception: %s (@s)', $@, $db->{connectlog});
        delete $db->{dbh};
        return;
    }
    
    if ($DBI::err || $DBI::errstr || !$db->{dbh}) {
        logerror($db, 'Connect[%s] %s (%s)', $DBI::err||'-null-', $DBI::errstr || '<unknown>', $db->{connectlog});
        delete $db->{dbh};
        return 0;
    }
    
    logquery($db, "Connected to: %s", $db->{connectlog});
    foreach my $sql (@{ $db->{onconnect} || [] }) {
        my $ret = $db->{dbh}->do($sql);
        logquery($db, "%s; Result: %s", $sql, $ret);
    }
    
    $db->{dbh};
}

sub _reconnect {
    my $db = shift() || return;
    
    delete $db->{dbh};
    
    return if $db->{reconnected} && ($db->{reconnected} > 10);
    
    logquery($db, "Reconnecting...");
    my $dbh = _connect($db) || return;
    
    $db->{reconnected} ||= 0;
    $db->{reconnected} ++;
    
    return $dbh;
}

sub _disconnect {
    my $db = shift() || return;
    my $dbh = $db->{dbh} || return;
    
    $dbh->disconnect() || return;
    delete $db->{dbh};
    delete $db->{reconnected};
    
    logquery($db, "Disconnected from: %s", $db->{connectlog});
    
    1;
}

sub tbl {
    my ($db, $tbl) = @_;
    
    $db || return;
    
    my $t = $db->{tbl}->{$tbl};
    if (!$t) {
        logerror($db, 'Unknown table `%s`', $tbl);
        return;
    }
    
    return '`'.$t.'`';
}


sub _dumpquery {
    my $s = shift;
    
    @_ || return $s;
    
    $s .= '; params: ' .
        join(', ', 
            map {
                if (defined $_) {
                    my $s = length($_) > 100 ? substr($_, 0, 100)."..." : $_;
                    $s =~ s/\'/\\\'/g;
                    "'$s'";
                } else {
                    "null/undef";
                }
            }
            @_
        );
    
    return $s;
}

sub execute {
    my ($db, $sql, @param) = @_;
    
    $db || return;
    delete $db->{reconnected};
    my $dbh = $db->{dbh} || _connect($db) || return;
    
    my $sth = $dbh->prepare($sql);
    if ($dbh->err() || $dbh->errstr() || !$sth) {
        logerror($db, "Query prepare[%s] %s", $dbh->err()||'-null-', $dbh->errstr() || '<unknown>');
        return;
    }

    logquery($db, _dumpquery($sql, @param));
    
    my $r = $sth->execute(@param);
    if (!$r || ($r < 0)) {
        my $err = $sth->err() || $DBI::err;
        logerror($db, "Execute[%s] %s; on query: %s", $err, $sth->errstr(), _dumpquery($sql, @param));
        if ($err && (($err == 2013) || ($err == 2006))) {
            _reconnect($db) || return;
            return execute($db, $sql, @param);
        }
        # Финишируем sth после реконнекта, чтобы не сбросилась $DBI::err
        $sth->finish();
        return;
    }
    
    delete $db->{reconnected};
    
    return $sth;
}

sub bindcols {
    my ($db, $sth, $tbl, $bind) = @_;
    
    $tbl = $1 if $tbl =~ /^\`(.+)\`$/;
    
    my @columns = @{ $sth->{mysql_table} };
    @columns = map { 
            my $table = shift @columns;
            my $column = $_;
            if (!$table) {
                ($table, $column) = split(/\./, $column, 2);
                ($table, $column) = ($tbl, $table) if !$column;
            }
            [$table, $column];
        } @{ $sth->{NAME_lc} };
        
    %$bind = ();
    my @bind =
        map {
            my ($table, $column) = @$_;
            my $h;
            if ($tbl eq $table) {
                $h = \$bind->{$column};
            }
            else {
                delete($bind->{$table})
                    if ref($bind->{$table}) ne 'HASH';
                $bind->{$table} ||= {};
                $h = \$bind->{$table}->{$column};
            }
            $h;
        } @columns;

    $sth->bind_columns( @bind );
    if ($DBI::err) {
        logerror($db, "Bind[%s] %s", $DBI::err, $sth->errstr());
        $sth->finish();
        return;
    }
    
    1;
}

sub fieldset {
    my @field = ();
    my @param = ();
    while (my $f = shift) {
        my $v = shift;
        next if $f !~ /^[a-zA-Z][a-zA-Z0-9_]*$/;
        if (ref($v) eq 'SCALAR') {
            push @field, '`'.$f.'` = '.$$v;
        }
        elsif (ref($v) eq 'ARRAY') {
            my ($func, @p) = @$v;
            my $n = @p;
            my $arg = join ', ', map { '?' } 1..$n;
            push @field, '`'.$f.'` = '.$func.'('.$arg.')';
            push @param, @p;
        }
        else {
            push @field, '`'.$f.'` = ?';
            push @param, $v;
        }
    }
    
    return join(', ', @field), @param;
}

sub do { _do(@_) }

sub _do {
    my ($db, $sql, @param) = @_;
    
    my $sth = execute($db, $sql, @param) || return;
    
    my $rows = $sth->rows();

    $sth->finish();
    logquery($db, "rows: %s", $rows);
    
    return $rows || '0E0';
}

sub insertid {
    my $db = shift() || return;
    my $dbh = $db->{dbh} || return;
    
    return $dbh->{'mysql_insertid'};
}

#############################################################################################

sub _srch {
    my ($db, $tbl, @srch) = @_;
    
    my $t = $db->{tbl}->{$tbl};
    if (!$t) {
        logerror($db, 'Unknown table `%s`', $tbl);
        return;
    }
    if (!@srch) {
        logerror($db, "Srch where null");
        return;
    }
    
    my %q = Clib::DB::MySQL::Srch::parse($db, $tbl, $t, @srch);
    
    $q{err} = 'unknown' if !%q;
        
    if ($q{err}) {
        logerror($db, "Srch args %s", $q{err});
        return;
    }
    
    my $sql = 'SELECT ';
    $sql .= 'SQL_CALC_FOUND_ROWS ' if $q{pager};
    $sql .=
                    join(', ', @{ $q{field} }) .
                ' FROM ' .
                    join(' ', map { $_->{code} } @{ $q{tbl} });
    $sql .= ' WHERE ' . $q{where} if $q{where};
    $sql .= ' GROUP BY ' . $q{group} if $q{group};
    $sql .= ' ORDER BY ' . $q{order} if $q{order};
    if (my $pager = $q{pager}) {
        if (!defined($pager->{start}) || ($pager->{start} !~ /^\d+$/)) {
            $pager->{page} ||= 1;
            $pager->{start} = (int($pager->{page})-1) * $pager->{onpage};
        }
        $sql .= ' LIMIT ' . $pager->{start} . ', ' . $pager->{onpage};
    }
    elsif ($q{limit}) {
        $sql .= ' LIMIT ' . $q{limit};
    }
    
    my $sth = execute($db, $sql, @{ $q{param} }) || return;
    my %col = ();
    bindcols($db, $sth, $t, \%col) || return;
    
    my $rows = $sth->rows();
    my @ret = ();
    if (my $hnd = $q{hnd}) {
        while ($sth->fetch()) {
            $hnd->( map { ref($_) eq 'HASH' ? { %$_ } : $_ } %col );
        }
    }
    else {
        while ($sth->fetch()) {
            push @ret, { map { ref($_) eq 'HASH' ? { %$_ } : $_ } %col };
        }
    }

    $sth->finish();
    logquery($db, "rows: %s", $rows);
    
    if (my $pager = $q{pager}) {
        $pager->{count} = $rows;
        if (my $sth = execute($db, 'SELECT FOUND_ROWS()')) {
            ($pager->{countall}) = $sth->fetchrow_array();
            $sth->finish();
        }
        $pager->{countall} ||= $rows;
        use POSIX qw(ceil);
        $pager->{pageall} = ceil($pager->{countall} / $pager->{onpage});
    }
    
    return $q{hnd} ? $rows||'0E0' : @ret;
}

#############################################################################################

sub _func {
    my ($db, $tbl, $sqlSel, @srch) = @_;
    
    my $t = $db->{tbl}->{$tbl};
    if (!$t) {
        logerror($db, 'Unknown table `%s`', $tbl);
        return;
    }
    
    my %q = Clib::DB::MySQL::Srch::parse($db, $tbl, $t, @srch);
    
    $q{err} = 'unknown' if !%q;
        
    if ($q{err}) {
        logerror($db, "Srch args %s", $q{err});
        return;
    }
    
    if ($q{pager}) {
        logerror($db, "Pager not allowed by Func-operation");
        return;
    }
    if (!$sqlSel) {
        logerror($db, "sql not specified for Func-operation");
        return;
    }
    
    my $sql = 'SELECT ' .
                $sqlSel .
                ' FROM ' .
                    join(' ', map { $_->{code} } @{ $q{tbl} });
    $sql .= ' WHERE ' . $q{where} if $q{where};
    $sql .= ' GROUP BY ' . $q{group} if $q{group};
    $sql .= ' ORDER BY ' . $q{order} if $q{order};
    $sql .= ' LIMIT ' . $q{limit} if $q{limit};
    
    my $sth = execute($db, $sql, @{ $q{param} }) || return;
    
    my $rows = $sth->rows();
    my @ret = ();
    if (my $hnd = $q{hnd}) {
        while (my @row = $sth->fetchrow_array()) {
            $hnd->( @row );
        }
    }
    else {
        while (my @row = $sth->fetchrow_array()) {
            push @ret, [@row];
        }
    }

    $sth->finish();
    logquery($db, "rows: %s", $rows) if $rows != 1;
    
    return $q{hnd} ? $rows||'0E0' : @ret > 1 ? @ret : shift(@ret);
}

sub _count {
    my ($db, $tbl, @srch) = @_;
    
    my @ret = _func($db, $tbl, 'COUNT(*)', @srch);
    
    if (wantarray) {
        return
            map { ref($_) eq 'ARRAY' ? @$_ : $_ }
            @ret;
    }
    
    my $ret = shift @ret;
    return ref($ret) eq 'ARRAY' ? $ret->[0] : $ret;
}

sub _max {
    my ($db, $tbl, $fld, @srch) = @_;
    
    if (!Clib::DB::MySQL::Srch::_is_field($fld)) {
        logerror($db, "Wrong fld-format for Max-Func: %s", $fld);
        return;
    }
    
    my @ret = _func($db, $tbl, 'MAX(`'.$fld.'`)', @srch);
    
    if (wantarray) {
        return
            map { ref($_) eq 'ARRAY' ? @$_ : $_ }
            @ret;
    }
    
    my $ret = shift @ret;
    return ref($ret) eq 'ARRAY' ? $ret->[0] : $ret;
}

#############################################################################################

sub _queryList {
    my ($db, $sql, @p) = @_;
    
    if (!$sql) {
        logerror($db, "SQL query is null");
        return;
    }
    
    my ($pager, $hnd, @param) = ();
    my $tbl = '';
    
    foreach my $p (@p) {
        if (ref($p) eq 'HASH') {
            $pager = $p if $p->{onpage} && ($p->{onpage} =~ /^\d+$/);
            $tbl = $p->{tbl} if $p->{tbl};
        }
        elsif (ref($p) eq 'CODE') {
            $hnd = $p;
        }
        else {
            push @param, $p;
        }
    }
    
    if ($pager) {
        if (!defined($pager->{start}) || ($pager->{start} !~ /^\d+$/)) {
            $pager->{page} ||= 1;
            $pager->{start} = (int($pager->{page})-1) * $pager->{onpage};
        }
        $sql =~ s/^SELECT\b/SELECT SQL_CALC_FOUND_ROWS/i;
        $sql .= ' LIMIT ' . $pager->{start} . ', ' . $pager->{onpage};
    }
    
    my $sth = execute($db, $sql, @param) || return;
    my %col = ();
    bindcols($db, $sth, $tbl, \%col) || return;
    
    my $rows = $sth->rows();
    my @ret = ();
    if ($hnd) {
        while ($sth->fetch()) {
            $hnd->( map { ref($_) eq 'HASH' ? { %$_ } : $_ } %col );
        }
    }
    else {
        while ($sth->fetch()) {
            push @ret, { map { ref($_) eq 'HASH' ? { %$_ } : $_ } %col };
        }
    }

    $sth->finish();
    logquery($db, "rows: %s", $rows);
    
    if ($pager) {
        $pager->{count} = $rows;
        if (my $sth = execute($db, 'SELECT FOUND_ROWS()')) {
            ($pager->{countall}) = $sth->fetchrow_array();
            $sth->finish();
        }
        $pager->{countall} ||= $rows;
        use POSIX qw(ceil);
        $pager->{pageall} = ceil($pager->{countall} / $pager->{onpage});
    }
    
    return $hnd ? $rows||'0E0' : @ret;
}

#############################################################################################


sub _get {
    my ($db, $tbl, $field, $id) = (shift, shift, @_ > 1 ? @_ : ('id', shift));
    
    $tbl = tbl($db, $tbl) || return;
    
    defined($id) || return;
    my @id = ref($id) eq 'ARRAY' ? @$id : $id;
    @id || return;
    
    return if $field !~ /^[a-zA-Z][a-zA-Z0-9_]*$/;
    #$field ||= 'id';

    my $where = join(' OR ', map { '`' . $field . '` = ?' } @id);
    
    my $sth = execute($db, 'SELECT * FROM '.$tbl.' WHERE '.$where, @id) || return;
    my %col = ();
    bindcols($db, $sth, $tbl, \%col) || return;
    
    my $rows = $sth->rows();
    my @ret = ();
    while ($sth->fetch()) {
        push @ret, { map { ($_ => ref($col{$_}) eq 'HASH' ? { %{ $col{$_} } } : $col{$_}) } keys %col };
    }

    $sth->finish();
    logquery($db, "rows: %s", $rows);
    
    #return !ref($id) || ((ref($id) eq 'ARRAY') && (@$id < 2)) ? $ret[0] : @ret;
    return (@ret > 1) || wantarray ? @ret : $ret[0];
}

sub _all {
    my ($db, $tbl, @orderby) = @_;
    
    $tbl = tbl($db, $tbl) || return;
    
    my $orderby = join (', ',
        map { s/^\-// ? '`'.$_.'` DESC' : '`'.$_.'`' }
        grep { /^\-?[a-zA-Z][a-zA-Z0-9_]*$/ }
        @orderby
    );
    $orderby = ' ORDER BY ' . $orderby if $orderby;
    
    my $sth = execute($db, 'SELECT * FROM ' . $tbl . $orderby) || return;
    my %col = ();
    bindcols($db, $sth, $tbl, \%col) || return;
    
    my $rows = $sth->rows();
    my @ret = ();
    while ($sth->fetch()) {
        push @ret, { map { ($_ => ref($col{$_}) eq 'HASH' ? { %{ $col{$_} } } : $col{$_}) } keys %col };
    }

    $sth->finish();
    logquery($db, "rows: %s", $rows);
    
    return @ret;
}

sub _add {
    my ($db, $tbl, @add) = @_;
    
    $tbl = tbl($db, $tbl) || return;
    
    my ($fields, @param) = fieldset(@add);
    
    _do($db, 'INSERT INTO '.$tbl.' SET '.$fields, @param) || return;
    
    my $id = insertid($db);
    logquery($db, "insertid: %s", $id);
    
    return $id;
}

sub _rep {
    my ($db, $tbl, @add) = @_;
    
    $tbl = tbl($db, $tbl) || return;
    
    my ($fields, @param) = fieldset(@add);
    
    my $ret = _do($db, 'REPLACE INTO '.$tbl.' SET '.$fields, @param) || return;
    
    if (my $id = insertid($db)) {
        logquery($db, "insertid: %s", $id);
        return $id;
    }
    
    return $ret;
}

sub _updf {
    my ($db, $tbl, $field, $key, @upd) = @_;
    
    $tbl = tbl($db, $tbl) || return;
    return if $field !~ /^[a-zA-Z][a-zA-Z0-9_]*$/;
    
    my ($fields, @param) = fieldset(@upd);
    
    return _do($db, 'UPDATE '.$tbl.' SET '.$fields.' WHERE `'.$field.'` = ?', @param, $key);
}

sub _upd {
    my ($db, $tbl, $id, @upd) = @_;
    
    return _updf($db, $tbl, 'id', $id, @upd);
}

sub _set {
    my ($db, $tbl, $field, $key, @upd) = @_;
    
    my $ret = _updf($db, $tbl,  $field, $key, @upd) || return;
    return $ret if $ret > 0;
    
    $tbl = tbl($db, $tbl) || return;
    return if $field !~ /^[a-zA-Z][a-zA-Z0-9_]*$/;
    
    my ($fields, @param) = fieldset(@upd);
    
    return _do($db, 'INSERT INTO '.$tbl.' SET `'.$field.'` = ?, '.$fields, $key, @param);
}

sub _del {
    my ($db, $tbl, $field, $id) = (shift, shift, @_ > 1 ? @_ : ('id', shift));
    
    $tbl = tbl($db, $tbl) || return;
    
    defined($id) || return;
    my @id = ref($id) eq 'ARRAY' ? @$id : $id;
    @id || return;
    
    return if $field !~ /^[a-zA-Z][a-zA-Z0-9_]*$/;
    #$field ||= 'id';

    my $where = join(' OR ', map { '`' . $field . '` = ?' } @id);
    
    return _do($db, 'DELETE FROM '.$tbl.' WHERE '.$where, @id) || return;
}

sub _ping {
    my $db = shift;
    
    return _do($db, 'SELECT 1');
}

sub _preFork {
    my $db = shift() || return;
    
    _ping() || return;
    
    my $dbh = $db->{dbh} || return;
    
    $dbh->{InactiveDestroy} = 1;
    1;
}

sub _mainFork {
    my $db = shift() || return;
    my $dbh = $db->{dbh} || return;
    
    $dbh->{InactiveDestroy} = 0;
    1;
}

sub _chldFork {
    my $db = shift() || return;
    my $dbh = $db->{dbh} || return;
    
    return $dbh->clone();
}

1;