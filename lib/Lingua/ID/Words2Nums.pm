package Lingua::ID::Words2Nums;

use 5.010;
use strict;
use warnings;
#use Log::Any qw($log);

# VERSION

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(words2nums words2nums_simple);

use vars qw(
               %Digits
               %Mults
               %Words
               $Neg_pat
               $Exp_pat
               $Dec_pat
       );

use Parse::Number::ID qw(parse_number_id);
use Scalar::Util qw(looks_like_number);

%Digits = (
    nol => 0, kosong => 0,
    se => 1, satu => 1,
    dua => 2,
    tiga => 3,
    empat => 4,
    lima => 5,
    enam => 6,
    tujuh => 7,
    delapan => 8,
    sembilan => 9,
);

%Mults = (
    puluh => 1e1,
    ratus => 1e2,
    ribu => 1e3,
    juta => 1e6,
    milyar => 1e9, milyard => 1e9, miliar => 1e9, miliard => 1e9,
    triliun => 1e12, trilyun => 1e12,
);

%Words = (
    %Digits,
    %Mults,
    belas => 0,
);

$Neg_pat  = '(?:negatif|min|minus)';
$Exp_pat  = '(?:(?:di)?kali(?:kan)? sepuluh pangkat)';
$Dec_pat  = '(?:koma|titik)';

sub words2nums($) { _handle_exp(@_) }
sub words2nums_simple($) { _handle_simple(@_) }

sub _handle_exp($) {
    my $words = lc shift;
    my ($num1, $num2);

    if( $words =~ /(.+)\s+$Exp_pat\s+(.+)/ ) {
        #$log->trace("it's an exponent");
        $num1 = _handle_neg($1);
        $num2 = _handle_neg($2);
        #$log->trace("num1 is $num1, num2 is $num2");
        !defined($num1) || !defined($num2) and return undef;
        return $num1 * 10 ** $num2;
    } else {
        #$log->trace("not an exponent");
        $num1 = _handle_neg($words);
        not defined $num1 and return undef;
        #$log->trace("num1 = $num1");
        return $num1;
    }
}

sub _handle_neg($) {
    my $words = lc shift;
    my $num1;

    if( $words =~ /^\s*$Neg_pat\s+(.+)/ ) {
        #$log->trace("it's negative");
        $num1 = -_handle_dec($1);
        not defined $num1 and return undef;
        #$log->trace("num1 = $num1");
        return $num1;
    } else {
        #$log->trace("it's not negative");
        $num1 = _handle_dec($words);
        not defined $num1 and return undef;
        #$log->trace("num1 = $num1");
        return $num1;
    }
}

sub _handle_dec($) {
    my $words = lc shift;
    my ($num1, $num2);

    if( $words =~ /(.+)\s+$Dec_pat\s+(.+)/ ) {
        #$log->trace("it has decimals (\$1=$1, \$2=$2)");
        $num1 = _handle_int($1);
        $num2 = _handle_simple($2);
        #$log->trace("num1 is $num1, num2 is $num2");
        !defined($num1) || !defined($num2) and return undef;
        return $num1 + ("0.".$num2);
    } else {
        #$log->trace("it's an integer");
        $num1 = _handle_int($words);
        not defined $num1 and return undef;
        #$log->trace("num1 is $num1");
        return $num1;
    }
}


# handle words before decimal (e.g, 'seratus dua puluh tiga', ...)
sub _handle_int($) {
    my @words = &_split_it( lc shift );
    my ($num, $mult);
    my $seen_digits = 0;
    my ($w, $a, $subtot, $tot);
    my @nums = ();

    $words[0] eq 'ERR' and return undef;
    #$log->trace("the words are @words");

    for $w (@words) {
        if( defined $Digits{$w} ) { # digits (satuan)
            #$log->trace("saw a digit: $w");
            $seen_digits and do { push @nums, ((10 * (pop @nums)) + $Digits{$w}) }
                or do { push @nums, $Digits{$w}; $seen_digits = 1 }
        }

        elsif ( looks_like_number $w ) { # digits (satuan) as number
            #$log->trace("saw a number: $w");
            return undef if $seen_digits; # 1 <spc> 2 is considered an error
            push @nums, $w;
            $seen_digits = 1;
        }

        elsif( $w eq 'belas' ) { # special case, teens (belasan)
            #$log->trace("saw a teen: $w");
            return undef unless $seen_digits; # mistake in writing teens
            push @nums, 10 + pop @nums;
            $seen_digits = 0;
        }

        else{ # must be a multiplier, or unknown
            #$log->trace( "saw a multiplier: $w");
            return undef unless defined $Mults{$w}; # unknown word
            return undef unless @nums; # mistake in writing tens/multiplier

            $a = 0; $subtot = 0;
               do { $a = pop @nums; $subtot += $a }
            until ( $a > $Mults{$w} || !@nums );

            if( $a > $Mults{$w} ) { push @nums, $a; $subtot -= $a }
            push @nums, $Mults{$w}*$subtot;
             $seen_digits = 0;
        }
    }

    # calculate total
    $tot = 0;
    while( @nums ){ $tot += shift @nums }
    $tot;
}


# handle words after decimal (simple with no 'belas', 'puluh', 'ratus', ...)
sub _handle_simple($) {
    #$log->tracef("-> _handle_simple(%s)", \@_);
    my @words = &_split_it( lc shift );
    #$log->tracef("words = %s", \@words);
    my ($num, $w);

    $words[0] eq 'ERR' and return undef;

    $num = "";
    for $w (@words) {
        if (looks_like_number $w) {
            $num .= $w;
        } else {
            not defined $Digits{$w} and return undef;
            $num .= $Digits{$w};
        }
    }

    $num;
}


# split string into array of words. also splits 'sepuluh' -> (se, puluh),
# 'tigabelas' -> (tiga, belas), etc.
sub _split_it($) {
    my $words = lc shift;
    my @words = ();
    my $w;

    for $w (split /\s+/, $words) {
        ##$log->trace("saw $w");
        if ($w =~ /^([-+]?[0-9.,]+(?:[Ee][+-]?\d+)?)(\D?.*)$/) {
            my ($n0, $w2) = ($1, $2);
            #print "n0=$n0, w2=$w2\n";
            my $n = parse_number_id(text => $n0);
            unless (defined $n) {
                unshift @words, 'ERR';
                last;
            }
            push @words, $n;
            push @words, $w2 if length($w2);
        }
        elsif( $w =~ /^se(.+)$/ and defined $Words{$1} ) {
            #$log->trace("i should split $w");
            push @words, 'se', $1 }
        elsif( $w =~ /^(.+)(belas|puluh|ratus|ribu|juta|mil[iy]ard?|tril[iy]un)$/ and defined $Words{$1} ) {
            #$log->trace("i should split $w");
            push @words, $1, $2 }
        elsif( defined $Words{$w} ) {
            push @words, $w }
        else {
            #$log->trace("i don't recognize $w");
            unshift @words, 'ERR';
            last;
        }
    }

    #use Data::Dump; dd \@words;
    @words;
}

1;
# ABSTRACT: Convert Indonesian verbage to number
__END__

=head1 SYNOPSIS

 use Lingua::ID::Words2Nums qw(words2nums words2nums_simple);

 print words2nums("seratus tiga koma dua");  # 103.2
 print words2nums("minus 3 juta 100 ribu");  # 3100000
 print words2nums("1,605 juta");             # 1605000
 print words2nums("-1.3e4");                 # 13000

 print words2nums_simple("satu dua tiga");   # 123


=head1 DESCRIPTION

This module provides two functions, B<words2nums> and B<words2nums_simple>. They
are the counterpart of L<Lingua::ID::Nums2Words>'s B<nums2words> and
B<nums2words_simple>.


=head2 FUNCTIONS

None are exported, but they are exportable.

=head2 words2nums(STR) => NUM|undef

Parse Indonesian verbage and return number, or undef if failed (unknown verbage
or 'syntax error'). In English, this is equivalent to converting "one hundred
and twenty three" to 123. Currently can handle real numbers in normal and
scientific form in the order of hundreds of trillions.

Will produce unexpected result if you feed it stupid verbage.

=head2 words2nums_simple(STR) => NUM|undef

Like B<words2nums>, but can only handle spelled digits (like "one two three" =>
123 in English).


=head1 SEE ALSO

L<Lingua::ID::Nums2Words>

L<Parse::Number::ID> is used to parse numbers in the verbage.

=cut
