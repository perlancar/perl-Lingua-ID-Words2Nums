package Lingua::ID::Words2Nums ;

use strict ;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK) ;

require Exporter ;

@ISA = qw(Exporter) ;
@EXPORT = qw(words2nums words2nums_simple) ;
$VERSION = '0.1' ;


### package globals

use vars qw(
	%Digits
	%Mults
	%Words
	$Neg_pat
	$Exp_pat
	$Dec_pat
) ;

BEGIN {
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
	sembilan => 9
) ;

%Mults = ( 
	puluh => 1e1, 
	ratus => 1e2, 
	ribu => 1e3, 
	juta => 1e6,
	milyar => 1e9, milyard => 1e9, miliar => 1e9, miliard => 1e9,
	triliun => 1e12, trilyun => 1e12
) ;

%Words = (
	%Digits,
	%Mults,
	belas => 0
) ;

$Neg_pat  = '(?:negatif|min|minus)' ;
$Exp_pat  = '(?:(?:di)?kali(?:kan)? sepuluh pangkat)' ;
$Dec_pat  = '(?:koma|titik)' ;
}


### public subs
sub words2nums($) { w2n1(@_) }
sub words2nums_simple($) { w2n5(@_) }

### private subs


# for debugging
use vars qw($DEBUG) ;
$DEBUG = 0 ;
sub hmm___ { print "(", (caller 1)[3], ") Hmm, ", @_ if $DEBUG }


# handle exponential
sub w2n1($) {
	my $words = lc shift ;
	my ($num1, $num2) ;

	if( $words =~ /(.+)\b$Exp_pat\b(.+)/ ) { 
		hmm___ "it's an exponent.\n" ;
		$num1 = w2n2($1) ;
		$num2 = w2n2($2) ;
		hmm___ "\$num1 is $num1, \$num2 is $num2\n" ;
		not defined $num1 or not defined $num2 and return undef ;
		return $num1 * 10 ** $num2
	} else {
		hmm___ "not an exponent.\n" ;
		$num1 = w2n2($words) ;
		not defined $num1 and return undef ;
		hmm___ "\$num1 = $num1\n" ;
		return $num1 
	}
}


# handle negative
sub w2n2($) {
	my $words = lc shift ;
	my $num1 ;

	if( $words =~ /^[\s\t]*$Neg_pat\b(.+)/ ) {
		hmm___ "it's negative.\n" ;
		$num1 = -w2n3($1) ;
		not defined $num1 and return undef ;
		hmm___ "\$num1 = $num1\n" ;
		return $num1
	} else {
		hmm___ "it's not negative.\n" ;
		$num1 = w2n3($words) ;
		not defined $num1 and return undef ;
		hmm___ "\$num1 = $num1\n" ;
		return $num1
	}
}


# handle decimal
sub w2n3($) {
	my $words = lc shift ;
	my ($num1, $num2) ;

	if( $words =~ /(.+)\b$Dec_pat\b(.+)/ ) {
		hmm___ "it has decimals.\n" ;
		$num1 = w2n4($1) ;
		$num2 = w2n5($2) ;
 		not defined $num1 or not defined $num2 and return undef ;
		hmm___ "\$num1 is $num1, \$num2 is $num2\n" ;
		return $num1 + "0.".$num2
	} else {
		hmm___ "it's an integer.\n" ;
		$num1 = w2n4($words) ;
		not defined $num1 and return undef ;
		hmm___ "\$num1 is $num1\n" ;
		return $num1
	}
}


# handle words before decimal (e.g, 'seratus dua puluh tiga', ...)
sub w2n4($) {
	my @words = &split_it( lc shift ) ;
	my ($num, $mult) ;
	my $seen_digits = 0 ;
	my ($w, $a, $subtot, $tot) ;
	my @nums = () ;

	$words[0] eq 'ERR' and return undef ;
	hmm___ "the words are @words.\n" ;

	for $w (@words) {
		if( defined $Digits{$w} ) { # digits (satuan)
			hmm___ "saw a digit: $w.\n" ;
      			$seen_digits and do { push @nums, ((10 * (pop @nums)) + $Digits{$w}) }
			or do { push @nums, $Digits{$w} ; $seen_digits = 1 }
		}

		elsif( $w eq 'belas' ) { # special case, teens (belasan)
			hmm___ "saw a teen: $w.\n" ;
			return undef unless $seen_digits ; # (salah penulisan belasan)
			push @nums, 10 + pop @nums ;
			$seen_digits = 0 ;
		}

		else{ # must be a multiplier
			hmm___ "saw a multiplier: $w.\n" ;
			return undef unless @nums ; # (salah penulisan puluhan/pengali)
	
			$a = 0 ; $subtot = 0 ;
   			do { $a = pop @nums ; $subtot += $a } 
			until ( $a > $Mults{$w} || !@nums ) ;

			if( $a > $Mults{$w} ) { push @nums, $a; $subtot -= $a }
			push @nums, $Mults{$w}*$subtot ;
 			$seen_digits = 0 ;
		}
	}

	# calculate total
	$tot = 0 ;
	while( @nums ){ $tot += shift @nums }
	$tot
}


# handle words after decimal (simple with no 'belas', 'puluh', 'ratus', ...)
sub w2n5($) {
	my @words = &split_it( lc shift ) ;
	my ($num, $mult, $w) ;

	$words[0] eq 'ERR' and return undef ;

	$num = 0 ;
	$mult = 1 ;
	for $w (reverse @words) {
		not defined $Digits{$w} and return undef ;
		$num += $Digits{$w}*$mult ;
		$mult *= 10 ;
	}

	$num
}


# split string into array of words. also splits 'sepuluh' -> (se, puluh),
# 'tigabelas' -> (tiga, belas), etc.
sub split_it($) {
	my $words = lc shift ;
	my @words = () ;
	my $w ;

	for $w ($words =~ /\b(\w+)\b/g) {
		hmm___ "saw $w.\n" ;
		if( $w =~ /^se(.+)$/ and defined $Words{$1} ) {
			hmm___ "i should split $w.\n" ;
			push @words, 'se', $1 }
		elsif( $w =~ /^(.+)(belas|puluh|ratus|ribu|juta|mil[iy]ard?|tril[iy]un)$/ and defined $Words{$1} ) {
			hmm___ "i should split $w.\n" ;
			push @words, $1, $2 }
		elsif( defined $Words{$w} ) {
			push @words, $w }
		else {
			hmm___ "i don't recognize $w.\n" ;
			unshift @words, 'ERR' ;
			last }
	}

	@words
}

1
__END__

=head1 NAME

Lingua::ID::Words2Nums - convert Indonesian verbage to number.

=head1 SYNOPSIS

  use Lingua::ID::Words2Nums ;
  
  print words2nums("seratus dua puluh tiga") ; # 123 
  print words2nums_simple("satu dua tiga") ;   # 123

=head1 DESCRIPTION

B<words2nums> currently can handle real numbers in normal and scientific 
form in the order of hundreds of trillions.

B<words2nums> will return B<undef> is its argument contains unknown 
verbage or "syntax error".

B<words2nums> will produce unexpected result if you feed it stupid 
verbage.

=head1 AUTHOR

Steven Haryanto E<lt>sh@hhh.indoglobal.comE<gt>

=head1 SEE ALSO

L<Lingua::ID::Nums2Words>

=cut
