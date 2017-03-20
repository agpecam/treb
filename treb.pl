#!/usr/bin perl

use strict;
use warnings;

use constant T_MONTH  => 0;
use constant T_DAY    => 1;
use constant T_HOUR   => 2;
use constant T_MINUTE => 3;
use constant T_SECOND => 4;

use constant TS_LEFT  => 0;
use constant TS_RIGHT => 1;

use constant C_SPACE => ' ';
use constant S_EMPTY => '';

my $VALID_TIMESTAMP =
  qr/^(Feb ( [1-9]|[12]\d)|(Apr|Jun|Sep|Nov) ( [1-9]|[12]\d|30)|(Jan|Mar|May|Jul|Aug|Oct|Dec) ( [1-9]|[12]\d|3[01])) ([0-1]\d|2[0-3]):[0-5]\d:[0-5]\d$/;

my %nmonth = (
              'Jan' => 0,
              'Feb' => 1,
              'Mar' => 2,
              'Apr' => 3,
              'May' => 4,
              'Jun' => 5,
              'Jul' => 6,
              'Aug' => 7,
              'Sep' => 8,
              'Oct' => 9,
              'Nov' => 10,
              'Dec' => 11
             );
my %rmonth = reverse %nmonth;
my @dmonth = (31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

# t_dlm(T_HOUR) = ':'
sub t_dlm($)
{
    my $t = shift
      ; # hereinafter '$t': term index - 0 for months, 1 for days, ..., 4 for seconds

    return $t > T_DAY ? ($t < T_SECOND ? ':' : S_EMPTY) : C_SPACE;
}

# t_str('Jan 19 16:25:11', T_DAY) = '19'
sub t_str($$)
{
    my ($ts, $t) =
      @_;  # hereinafter '$ts': timestamp string in a form of 'Mmm dd hh:mm:ss'

    return $t == T_MONTH ? substr($ts, 0, 3) : substr($ts, $t * 3 + 1, 2);
}

# t_int('Jan 19 16:25:11', T_HOUR) = 16
sub t_int($$)
{
    my ($ts, $t) = @_;

    return $t == T_MONTH ? $nmonth{t_str($ts, $t)} : int(t_str($ts, $t));
}

# t_tos(3, T_DAY) = ' 3'
sub t_tos($$)
{
    my ($val, $t) = @_;

    return $t != T_MONTH
      ? ($val < 10 ? ($t == T_DAY ? " $val" : "0$val") : "$val")
      : $rmonth{$val};
}

# t_mod('Jan 19 16:25:11', T_DAY) = 31
sub t_mod($$)
{
    my ($ts, $t) = @_;

    return $t > T_MONTH
      ? ($t < T_MINUTE ? ($t == T_DAY ? $dmonth[t_int($ts, T_MONTH)] : 24) : 60)
      : 12;
}

# t_dec('Jan 19 16:25:11', T_DAY) = 'Jan 18 23:59:59'
sub t_dec($$)
{
    my ($ts, $t) = @_;

    my $tn = t_tos((t_int($ts, $t) - 1 + t_mod($ts, $t)) % t_mod($ts, $t), $t);
    $tn = substr($ts, 0, $t * 3 + ($t > T_MONTH ? 1 : 0)) . $tn . t_dlm($t);

    return $tn
      . ($t < T_SECOND
         ? substr(ts_max($tn, $t + 1), ($t + 1) * 3 + 1)
         : S_EMPTY);
}

# t_inc('Jan 19 16:25:11', T_HOUR) = 'Jan 19 17:00:00'
sub t_inc($$)
{
    my ($ts, $t) = @_;

    my $tn = t_tos(
                   (t_int($ts, $t) + 1 - ($t == T_DAY ? 1 : 0))
                   % t_mod($ts, $t) + ($t == T_DAY ? 1 : 0),
                   $t
                  );
    $tn = substr($ts, 0, $t * 3 + ($t > T_MONTH ? 1 : 0)) . $tn . t_dlm($t);

    return $tn
      . ($t < T_SECOND
         ? substr(ts_min($tn, $t + 1), ($t + 1) * 3 + 1)
         : S_EMPTY);
}

# t_min('Jan 19 16:25:11', T_DAY) = 'Jan  1 00:00:00'
sub ts_min($$)
{
    my ($ts, $t) = @_;

    return
        substr($ts, 0, $t * 3 + ($t > T_MONTH ? 1 : 0))
      . substr(t_str($ts, 0) . '  1 00:00:00', $t * 3 + ($t > T_MONTH ? 1 : 0));
}

# t_max('Jan 19 16:25:11', T_DAY) = 'Jan 31 23:59:59'
sub ts_max($$)
{
    my ($ts, $t) = @_;

    my $mnt =
      $t == T_MONTH ? (t_int($ts, T_MONTH) + 11) % 12 : t_int($ts, T_MONTH);
    my $mts = $rmonth{$mnt} . C_SPACE . $dmonth[$mnt] . ' 23:59:59';

    return
        substr($ts, 0, $t * 3 + ($t > T_MONTH ? 1 : 0))
      . substr($mts, $t * 3 + ($t > T_MONTH ? 1 : 0));
}

# ts_tail('Jan 19 16:25:11', T_HOUR) = '16:25:11'
sub ts_tail($$)
{
    my ($ts, $t) = @_;

    return $t > T_MONTH
      ? ($t <= T_SECOND ? substr($ts, $t * 3 + 1) : S_EMPTY)
      : $ts;
}

# t_digit_scope('Jan 30 16:25:11', T_DAY, 0) = ('0', '1')
# t_digit_scope('Jan 30 16:25:11', T_DAY, 1) = (' ', '3')
sub t_digit_scope($$;$)
{
    my ($ts, $t, $rank) = @_;

    $rank = 0 unless defined $rank;

    my $m = t_int($ts, T_MONTH);
    my $d = int(t_int($ts, T_DAY) / 10);
    my $h = int(t_int($ts, T_HOUR) / 10);

    if ($t == T_DAY)
    {
        if ($rank == 0)
        {
            return ('1', '9') if $d == 0;
            return ('0', '9') if $d == 1 or $d == 2;
            return ($d == 3 and ($m == 3 or $m == 5 or $m == 8 or $m == 10))
              ? ('0', '0')
              : ('0', '1');
        }
        else
        {
            return $m == 1 ? (' ', '2') : (' ', '3');
        }
    }
    elsif ($t == T_HOUR)
    {
        if ($rank == 0)
        {
            return $h == 2 ? ('0', '3') : ('0', '9');
        }
        else
        {
            return ('0', '2');
        }
    }
    elsif ($t == T_MINUTE or $t == T_SECOND)
    {
        return $rank == 0 ? ('0', '9') : ('0', '5');
    }
}

# t_digit_range_regex(3, 5) = '[3-5]'
sub t_digit_range_regex($$;$)
{
    my ($d1, $d2, $dscope) = @_;

    my $d1i = $d1 eq C_SPACE ? 0 : int($d1);
    my $d2i = $d2 eq C_SPACE ? 0 : int($d2);

    return S_EMPTY
      if defined $dscope
      and $d1 eq @$dscope[0]
      and $d2 eq @$dscope[1];
    return "$d1"       if $d1i == $d2i;
    return "[$d1$d2]"  if $d2i - $d1i == 1;
    return "[$d1-$d2]" if $d2i - $d1i > 1;
    return S_EMPTY;
}

# t_range_regex('Jan 19 16:25:11', 'Jan 23 22:17:43', T_DAY) = '19|2[0-3]'
sub t_range_regex($$$)
{
    my ($ts1, $ts2, $t) = @_;
    my ($t1, $t2, $t1H, $t1L, $t2H, $t2L, $r1, $r2, @rs);

    return S_EMPTY
      if ts_tail($ts1, $t) eq ts_tail(ts_min($ts1, $t), $t)
      and ts_tail($ts2, $t) eq ts_tail(ts_max($ts1, $t), $t);

    $t1 = t_str($ts1, $t);
    $t2 = t_str($ts2, $t);

    return $t1 if $t1 eq $t2;

    if ($t == T_MONTH)
    {
        for ($r1 = $nmonth{$t1}; $r1 != $nmonth{$t2}; $r1 = ($r1 + 1) % 12)
        {
            push @rs, $rmonth{$r1};
        }
        push @rs, $rmonth{$r1};
    }
    else
    {
        return S_EMPTY if int($t2) < int($t1);

        $t1H = substr($t1, 0, 1);
        $t1L = substr($t1, 1, 1);
        $t2H = substr($t2, 0, 1);
        $t2L = substr($t2, 1, 1);

        my @ds1 = t_digit_scope($ts1, $t);
        my @ds2 = t_digit_scope($ts2, $t);

        return $t1H . t_digit_range_regex($t1L, $t2L, \@ds1) if $t1H eq $t2H;

        if (($r1 = t_digit_range_regex($t1L, $ds1[1], \@ds1)) ne S_EMPTY)
        {
            push @rs, "$t1H" . "$r1";
            $t1H = $t1H ne C_SPACE ? sprintf("%d", int($t1H) + 1) : '1';
        }

        if (($r1 = t_digit_range_regex($ds2[0], $t2L, \@ds2)) ne S_EMPTY)
        {
            push @rs, $r2
              if ($r2 = t_digit_range_regex($t1H, sprintf("%d", int($t2H) - 1)))
              ne S_EMPTY;
            push @rs, "$t2H" . "$r1";
        }
        else
        {
            push @rs, $r2 if ($r2 = t_digit_range_regex($t1H, $t2H)) ne S_EMPTY;
        }
    }

    return @rs ? join('|', @rs) : S_EMPTY;
}

# ts_regex(TS_LEFT,  'Jan 19 16:25:11') =
#   'Jan (19 (16:(25:(1[1-9]|[2-5])|2[6-9]|[3-5])|1[7-9]|2)|[23])'
# ts_regex(TS_RIGHT, 'Jan 19 16:25:11') =
#   'Jan (19 (16:(25:(0|1[01])|[01]|2[0-4])|0|1[0-5])| |1[0-8])'
sub ts_regex($$;$$);

sub ts_regex($$;$$)
{
    my ($tside, $ts, $t, $ulevel) = @_;
    my ($rt, @rs);

    $t      = T_MONTH unless defined $t;
    $ulevel = 1       unless defined $ulevel;

    return S_EMPTY unless $t >= T_MONTH and $t <= T_SECOND;
    return S_EMPTY
      if $t <= T_SECOND - $ulevel and ts_tail($ts, $t + $ulevel) eq ts_tail(
                                                    $tside == TS_LEFT
                                                    ? ts_min($ts, $t + $ulevel)
                                                    : ts_max($ts, $t + $ulevel),
                                                    $t + $ulevel
      );

    if ($t < T_SECOND and ($rt = ts_regex($tside, $ts, $t + 1, 0)) ne S_EMPTY)
    {
        $rt = t_str($ts, $t) . t_dlm($t) . ($rt =~ m/\|[^)]+$/ ? "($rt)" : $rt);
        push @rs, $rt;
    }

    $rt = S_EMPTY;

    if ($t and not $ulevel)
    {
        my $di = $ts;
        my $dm = $tside == TS_LEFT ? ts_max($ts, $t) : ts_min($ts, $t);

        if ($tside == TS_LEFT)
        {
            $di = t_inc($ts, $t)
              if t_int($ts, $t) < t_int($dm, $t)
              and scalar @rs;
            $rt = t_range_regex($di, $dm, $t) if not @rs or @rs and $di ne $ts;
        }
        else
        {
            $di = t_dec($ts, $t)
              if t_int($ts, $t) > t_int($dm, $t)
              and scalar @rs;
            $rt = t_range_regex($dm, $di, $t) if not @rs or @rs and $di ne $ts;
        }
    }

    push @rs, $rt if $rt ne S_EMPTY;

    return @rs ? join('|', @rs) : S_EMPTY;
}

# ts_range_regex('Jan 19 16:25:11', 'Jan 23 22:17:43') =
#   '^Jan (19 (16:(25:(1[1-9]|[2-5])|2[6-9]|[3-5])|1[7-9]|2)|
##        ^---ts_regex(TS_LEFT, 'Jan 19 16:25:11', T_DAY)--^        
#   2[0-2]|
##  ^----^ t_range_regex('Jan 20 00:00:00', 'Jan 22 23:59:59, T_DAY)
#   23 (22:(17:([0-3]|4[0-3])|0|1[0-6])|[01]|2[01]))'
##  ^-ts_regex(TS_RIGHT, 'Jan 23 22:17:43', T_DAY)-^
sub ts_range_regex($$)
{
    my ($ts1, $ts2) = @_;
    my ($t, $rl, $rm, $rr, @tl, $rs);

    for ($t = T_MONTH;
         $t <= T_SECOND and t_str($ts1, $t) eq t_str($ts2, $t);
         $t++)
    {
        $rs .= t_str($ts1, $t) . t_dlm($t);
    }

    ($t == T_MONTH or $t > T_SECOND or t_int($ts1, $t) < t_int($ts2, $t))
      or die "ERROR! '$ts1' > '$ts2'\n";

    if ($t <= T_SECOND)
    {
        $ts1 = t_inc($ts1, $t)
          if ($rl = ts_regex(TS_LEFT, $ts1, $t)) ne S_EMPTY;
        $ts2 = t_dec($ts2, $t)
          if ($rr = ts_regex(TS_RIGHT, $ts2, $t)) ne S_EMPTY;
        $rm = t_range_regex($ts1, $ts2, $t);
        $rm = "($rm)"
          if $rm =~ m/\|[^)]+$/
          and $rl eq S_EMPTY
          and $rr eq S_EMPTY;

        push @tl, $rl if $rl ne S_EMPTY;
        push @tl, $rm if $rm ne S_EMPTY;
        push @tl, $rr if $rr ne S_EMPTY;

        $rs .= @tl ? (@tl > 1 ? '(' . join('|', @tl) . ')' : $tl[0]) : S_EMPTY;
    }

    return defined $rs ? "^$rs" : '^';
}

(scalar @ARGV == 2)
  or die
  "Usage: treb.pl timestamp_begin timestamp_end, for example: treb 'Jan  1 00:00:00' 'Jul  3 23:59:59'\n";

my ($ts1, $ts2) = @ARGV;

($ts1 =~ m/$VALID_TIMESTAMP/) or die "ERROR! '$ts1' - invalid timestamp\n";
($ts2 =~ m/$VALID_TIMESTAMP/) or die "ERROR! '$ts2' - invalid timestamp\n";

print ts_range_regex($ts1, $ts2);
