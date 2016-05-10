# -*- mode: cperl -*-
# ${license-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/modules";
use CAF::RuleBasedEditor qw(:rule_constants);
use Readonly;
use CAF::Object;
use Test::More tests => 8;
use Test::NoWarnings;
use Test::Quattor;
use Test::Quattor::Object;
use Carp qw(confess);

Test::NoWarnings::clear_warnings();


=pod

=head1 SYNOPSIS

Basic test for rule-based editor (line pattern build)

=cut

Readonly my $FILENAME => '/my/file';

my $obj = Test::Quattor::Object->new();

$SIG{__DIE__} = \&confess;


my $fh = CAF::RuleBasedEditor->open($FILENAME, log => $obj);
ok(defined($fh), $FILENAME." was opened");


# Build a line pattern without a parameter value
Readonly my $KEYWORD => 'DPNS_HOST';
Readonly my $LINE_PATTERN_ENV_VAR => '#?\s*export\s+DPNS_HOST=';
Readonly my $LINE_PATTERN_KEY_VALUE => '#?\s*DPNS_HOST';
my $escaped_pattern = $fh->_buildLinePattern($KEYWORD,
                                             LINE_FORMAT_ENV_VAR);
is($escaped_pattern, $LINE_PATTERN_ENV_VAR, "Environment variable pattern ok");
$escaped_pattern = $fh->_buildLinePattern($KEYWORD,
                                          LINE_FORMAT_KEY_VAL);
is($escaped_pattern, $LINE_PATTERN_KEY_VALUE, "Key/value pattern ok");

# Build a line pattern without a parameter value
Readonly my $VALUE_1 => 'dpns.example.com';
Readonly my $EXPECTED_PATTERN_1 => '#?\s*export\s+DPNS_HOST=dpns\.example\.com';
Readonly my $VALUE_2 => 0;
Readonly my $EXPECTED_PATTERN_2 => '#?\s*export\s+DPNS_HOST=0';
Readonly my $VALUE_3 => '^dp$n-s.*ex] a+m(ple[.c)o+m?';
Readonly my $EXPECTED_PATTERN_3 => '#?\s*export\s+DPNS_HOST=\^dp\$n\-s\.\*ex\]\s+a\+m\(ple\[\.c\)o\+m\?';
# Test \ escaping separately as it also needs the expected value also needs to be escaped for the test
# to be successful!
Readonly my $VALUE_4 => 'a\b';
Readonly my $EXPECTED_PATTERN_4 => '#?\s*export\s+DPNS_HOST=a\\\\b';
$escaped_pattern = $fh->_buildLinePattern($KEYWORD,
                                          LINE_FORMAT_ENV_VAR,
                                          $VALUE_1);
is($escaped_pattern, $EXPECTED_PATTERN_1, "Environment variable with value (host name): pattern ok");
$escaped_pattern = $fh->_buildLinePattern($KEYWORD,
                                          LINE_FORMAT_ENV_VAR,
                                          $VALUE_2);
is($escaped_pattern, $EXPECTED_PATTERN_2, "Environment variable with value (0): pattern ok");
$escaped_pattern = $fh->_buildLinePattern($KEYWORD,
                                          LINE_FORMAT_ENV_VAR,
                                          $VALUE_3);
is($escaped_pattern, $EXPECTED_PATTERN_3, "Environment variable with value (special characters): pattern ok");
$escaped_pattern = $fh->_buildLinePattern($KEYWORD,
                                          LINE_FORMAT_ENV_VAR,
                                          $VALUE_4);
is($escaped_pattern, $EXPECTED_PATTERN_4, "Environment variable with value (backslash): pattern ok");


# Test::NoWarnings::had_no_warnings();
