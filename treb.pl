#!/usr/bin/env perl

use strict;
use warnings;

use constant T_LEFT  => 0;
use constant T_RIGHT => 1;
use constant C_SPACE => ' ';
use constant S_EMPTY => '';

my $TIMESTAMP = qr/^(Feb ( [1-9]|[12]\d)|(Apr|Jun|Sep|Nov) ( [1-9]|[12]\d|30)|(Jan|Mar|May|Jul|Aug|Oct|Dec) ( [1-9]|[12]\d|3[01])) ([0-1]\d|2[0-3]):[0-5]\d:[0-5]\d$/;

my %nmonth = ('Jan' => 0, 'Feb' => 1, 'Mar' => 2, 'Apr' => 3, 'May' => 4, 'Jun' => 5, 'Jul' => 6, 'Aug' => 7, 'Sep' => 8, 'Oct' => 9, 'Nov' => 10, 'Dec' => 11);
my %rmonth = reverse %nmonth;
my @dmonth = (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

sub t_delimiter($) {
	return $_[0] > 1 ? ($_[0] < 4 ? ':' : S_EMPTY) : C_SPACE;
}

sub t_str($$) {
	my ($ts, $t) = @_;

	return $t == 0 ? substr($ts, 0, 3) : substr($ts, $t * 3 + 1, 2);
}

sub t_int($$) {
	my ($ts, $t) = @_;

	return $t == 0 ? $nmonth{t_str($ts, $t)} : int(t_str($ts, $t));
}

sub t_itos($$) {
	my ($i, $t) = @_;

	return $t != 0 ? ($i < 10 ? ($t == 1 ? " $i" : "0$i") : "$i") : $rmonth{$i};
}

sub t_mod($$) {
	my ($ts, $t) = @_;

	return $t > 0 ? ($t < 3 ? ($t == 1 ? $dmonth[t_int($ts, 0)] : 24): 60) : 12;
}

sub t_dec($$) {
	my ($ts, $t) = @_;
	
	my $tn = t_itos((t_int($ts, $t) - 1 + t_mod($ts, $t)) % t_mod($ts, $t), $t);
	$tn = substr($ts, 0, $t * 3 + ($t ? 1 : 0)) . $tn . t_delimiter($t);

	return $tn . ($t < 4 ? substr(ts_max($tn, $t + 1), ($t + 1) * 3 + 1) : S_EMPTY);	
}

sub t_inc($$) {
	my ($ts, $t) = @_;

	my $tn = t_itos((t_int($ts, $t) + 1 - ($t == 1 ? 1 : 0)) % t_mod($ts, $t) + ($t == 1 ? 1 : 0), $t);
	$tn = substr($ts, 0, $t * 3 + ($t ? 1 : 0)) . $tn . t_delimiter($t);

	return $tn . ($t < 4 ? substr(ts_min($tn, $t + 1), ($t + 1) * 3 + 1) : S_EMPTY);	
}

sub ts_rest($$) {
	my ($ts, $t) = @_;

	return $t > 0 ? ($t < 5 ? substr($ts, $t * 3 + 1) : S_EMPTY) : $ts;
}

sub ts_min($$) {
	my ($ts, $t) = @_;

	return substr($ts, 0, $t * 3 + ($t ? 1 : 0)) . substr(t_str($ts, 0) . '  1 00:00:00', $t * 3 + ($t ? 1 : 0));
}

sub ts_max($$) {
	my ($ts, $t) = @_;

	my $mnt = $t == 0 ? (t_int($ts, 0) + 11) % 12 : t_int($ts, 0);
	my $mts = $rmonth{$mnt} . C_SPACE . $dmonth[$mnt] . ' 23:59:59';

	return substr($ts, 0, $t * 3 + ($t ? 1 : 0)) . substr($mts, $t * 3 + ($t ? 1 : 0));
}

sub d2_range($$) {
	my ($ts, $t) = @_;

	my $m = t_int($ts, 0);
	my $d = int(t_int($ts, 1) / 10);
	my $h = int(t_int($ts, 2) / 10);

	if ($t == 1) {
		return ('1', '9') if $d == 0;
		return ('0', '9') if $d == 1 or $d == 2;
		return ($d == 3 and ($m == 3 or $m == 5 or $m == 8 or $m == 10)) ? ('0', '0') : ('0', '1');
	}
	
	return ($h == 2 ? ('0', '3') : ('0', '9')) if $t == 2;
	return ('0', '9');
}

sub d_range_regex($$) {
	my ($db, $de) = @_;

	my $dbi = $db eq C_SPACE ? 0 : int($db);
	my $dei = $de eq C_SPACE ? 0 : int($de);
	
	return "$db"		if $dbi == $dei;
	return "[$db$de]"	if $dei - $dbi == 1;
	return "[$db-$de]"	if $dei - $dbi > 1;
	return S_EMPTY;
}

sub d2_range_regex($$$) {
	my ($db, $de, $dr) = @_;

	return S_EMPTY	if $db eq @$dr[0] and $de eq @$dr[1];
	return "$db"		if $db eq $de;
	return "[$db$de]"	if int($de) - int($db) == 1;
	return "[$db-$de]"	if int($de) - int($db) > 1;
	return S_EMPTY;
}

sub t_range_regex($$$) {
	my ($tsb, $tse, $t) = @_;
	my ($tb, $te, $tbh, $tbl, $teh, $tel, $t1, $t2, @rs);
	
	return S_EMPTY if ts_rest($tsb, $t) eq ts_rest(ts_min($tsb, $t), $t) and ts_rest($tse, $t) eq ts_rest(ts_max($tsb, $t), $t);

	$tb = t_str($tsb, $t); $te = t_str($tse, $t);

	return $tb if $tb eq $te;

	if ($t == 0) {
		for ($t1 = $nmonth{$tb}; $t1 != $nmonth{$te}; $t1 = ($t1 + 1) % 12) {
			push @rs, $rmonth{$t1};
		}
		push @rs, $rmonth{$t1};
	} else {
		return S_EMPTY if int($te) < int($tb);

		$tbh = substr($tb, 0, 1); $tbl = substr($tb, 1, 1);
		$teh = substr($te, 0, 1); $tel = substr($te, 1, 1);

		my @drb = d2_range($tsb, $t);
		my @dre = d2_range($tse, $t);

		return $tbh . d2_range_regex($tbl, $tel, \@drb) if $tbh eq $teh;

		if (($t1 = d2_range_regex($tbl, $drb[1], \@drb)) ne S_EMPTY) {
			push @rs, "$tbh$t1";
			$tbh = $tbh ne C_SPACE ? sprintf("%d", int($tbh) + 1) : '1';
		}

		if (($t1 = d2_range_regex($dre[0], $tel, \@dre)) ne S_EMPTY) {
			push @rs, $t2 if ($t2 = d_range_regex($tbh, sprintf("%d", int($teh) - 1))) ne S_EMPTY;
			push @rs, "$teh$t1";
		} else {
			push @rs, $t2 if ($t2 = d_range_regex($tbh, $teh)) ne S_EMPTY;
		}
	}

	return scalar @rs ? join('|', @rs) : S_EMPTY;
}

sub t_tail_regex($$;$$);

sub t_tail_regex($$;$$) {
	my ($tside, $ts, $t, $ulevel) = @_;
	my ($rt, @rs);

	$t = 0 unless defined $t;
	$ulevel = 1 unless defined $ulevel;

	return S_EMPTY unless $t >= 0 and $t <= 4;
	return S_EMPTY if $t < 5 - $ulevel and ts_rest($ts, $t + $ulevel) eq ts_rest($tside == T_LEFT ? ts_min($ts, $t + $ulevel) : ts_max($ts, $t + $ulevel), $t + $ulevel);

	if ($t < 4 and ($rt = t_tail_regex($tside, $ts, $t + 1, 0)) ne S_EMPTY) {
		$rt = t_str($ts, $t) . t_delimiter($t) . ($rt =~ m/\|[^)]+$/ ? "($rt)" : $rt);
		push @rs, $rt;
	}

	$rt = S_EMPTY;

	if ($t and not $ulevel) {
		my $di = $ts;
		my $dm = $tside == T_LEFT ? ts_max($ts, $t) : ts_min($ts, $t);


		if ($tside == T_LEFT) {
			$di = t_inc($ts, $t) if t_int($ts, $t) < t_int($dm, $t) and scalar @rs;
			$rt = t_range_regex($di, $dm, $t) if not scalar @rs or scalar @rs and (t_int($di, $t) != t_int($dm, $t) or $di ne $ts);
		} else {
			$di = t_dec($ts, $t) if t_int($ts, $t) > t_int($dm, $t) and scalar @rs;
			$rt = t_range_regex($dm, $di, $t) if not scalar @rs or scalar @rs and (t_int($di, $t) != t_int($dm, $t) or $di ne $ts);
		}
	}

	push @rs, $rt if $rt ne S_EMPTY;

	return scalar @rs ? join('|', @rs) : S_EMPTY;
}

sub treg($$) {
	my ($tsb, $tse) = @_;
	my ($t, $tb, $te, @tl, $rl, $rm, $rr, $rs);

	for ($t = 0; $t < 5 and t_str($tsb, $t) eq t_str($tse, $t); $t++) {
		$rs .= t_str($tsb, $t) . t_delimiter($t);	
	}

	($t == 0 or $t == 5 or t_int($tsb, $t) < t_int($tse, $t)) or die "ERROR! '$tsb' > '$tse'\n";

	if ($t < 5) {
		$tb = $tsb; $te = $tse;

		$tb = t_inc($tsb, $t) if ($rl = t_tail_regex(T_LEFT , $tsb, $t)) ne S_EMPTY;
		$te = t_dec($tse, $t) if ($rr = t_tail_regex(T_RIGHT, $tse, $t)) ne S_EMPTY;
		$rm = t_range_regex($tb, $te, $t); 
		$rm = "($rm)" if $rm =~ m/\|[^)]+$/ and $rl eq S_EMPTY and $rr eq S_EMPTY;

		push @tl, $rl if $rl ne S_EMPTY;
		push @tl, $rm if $rm ne S_EMPTY;
		push @tl, $rr if $rr ne S_EMPTY;

		$rs .= scalar @tl ? (scalar @tl > 1 ? '(' . join('|', @tl) . ')' : $tl[0]) : S_EMPTY;
	}

	return defined $rs ? "^$rs" : '^';
}

(scalar @ARGV == 2) or die "Usage: treb timestamp_begin timestamp_end, for example: treb 'Jan  1 00:00:00' 'Jul  3 23:59:59'\n";

my ($tsb, $tse) = @ARGV;

($tsb =~ m/$TIMESTAMP/) or die "ERROR! '$tsb' - invalid timestamp\n";
($tse =~ m/$TIMESTAMP/) or die "ERROR! '$tse' - invalid timestamp\n";

print treg($tsb, $tse);
