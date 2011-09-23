#!perl

use 5.010;
use strict;
use warnings;
use Test::More;

use Lingua::ID::Words2Nums qw(words2nums words2nums_simple $Pat);

my %test_n2w = (
    0 => "nol",
    1 => "satu",
    -1 => "negatif satu",
    10 => "sepuluh",
    10.1 => "sepuluh koma satu",
    10.01 => "sepuluh koma nol satu",
    10.012 => "sepuluh koma nol satu dua",
    11 => "sebelas",
    12 => "dua belas",
    13 => "3belas",
    18 => "lapan belas", # singkatan
    19 => "smbln bls", # singkatan
    14.23 => "14.23",
    -14.24 => "-14.24",
    15.24 => "1,524e+1",
    15.25 => "1,525e-1 ratus",
    21 => "dua puluh satu",
    99 => "sembilan puluh sembilan",
    100 => "seratus",
    101 => "seratus satu",
    -110 => "negatif seratus sepuluh",
    111 => "seratus sebelas",
    132 => "seratus tiga puluh dua",
    1000 => "seribu",
    2100 => "2ribu seratus",
    990002 => "9 ratus 90 ribu 2",
    2000000 => "dua juta",
    2010203 => "dua juta sepuluh ribu dua ratus tiga",
    -2004005 => "negatif dua juta empat ribu lima",
    9500000 => "9.5 juta",
    9630100 => "9,60 juta 30 ribu 100",
    3000000000 => "tiga milyar",
    3000000000.009 => "tiga milyar koma nol nol sembilan",
    3123456789 => "tiga milyar seratus dua puluh tiga juta ".
        "empat ratus lima puluh enam ribu tujuh ratus delapan puluh sembilan",
    -4000000000000 => "negatif empat triliun",
    994000000000000 => "sembilan ratus sembilan puluh empat triliun",
    9100000000000000 => "sembilan kuadriliun seratus triliun",

    "5.4e6" => "lima koma empat kali sepuluh pangkat enam",
    "-5.4e6" => "negatif lima koma empat kali sepuluh pangkat enam",
    "5.4e-6" => "lima koma empat kali sepuluh pangkat negatif enam",
    "-5.4e-6" => "negatif lima koma empat kali sepuluh pangkat negatif enam",

);
for (sort {abs($a) <=> abs($b)} keys %test_n2w) {
    ok(abs(words2nums($test_n2w{$_}) - $_) < 1e-7, "$test_n2w{$_} => $_")
        or diag "result: ".words2nums($test_n2w{$_});
}

my %test_n2ws = (
    0 => "nol",
    1 => "satu",
    10 => "satu nol",
    101 => "satu nol satu",
    12345 => "1 dua 3 4 lima",
    12346 => "123 empat enam",
    1234567890 => "satu dua tiga empat lima enam tujuh delapan sembilan nol",
);
for (sort {abs($a) <=> abs($b)} keys %test_n2ws) {
    ok(words2nums_simple($test_n2ws{$_}) == $_, "simple: $test_n2ws{$_} => $_")
        or diag "result: ".words2nums_simple($test_n2ws{$_});
}

my %test_pat = (
    "enam" => 1,
    "tujuh puluh tujuh" => 1,
    "tujuhpuluhtujuh" => 1,
    "tjhratusratus ratus" => 1,
    "setujuh" => 0,
    "se tujuh" => 1,
    "tujuh rts delapan plh 5" => 1,
    "7,5 jt rupiah" => 1,
    "0.51 miliar" => 1,
);

for (sort keys %test_pat) {
    my $match = $_ =~ /\b$Pat\b/;
    if ($test_pat{$_}) {
        ok($match, "'$_' matches");
    } else {
        ok(!$match, "'$_' doesn't match");
    }
}

done_testing();
