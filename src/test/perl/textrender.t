# -*- perl -*-
use strict;
use warnings;
use Test::More;
use Test::Quattor;
use CAF::TextRender;
use Test::MockModule;
use Cwd;

use B qw(svref_2object);

# http://stackoverflow.com/questions/7419071/determining-the-subroutine-name-of-a-perl-code-reference
sub get_name {
    my $sub_ref = shift;
    my $cv = svref_2object ( $sub_ref );
    my $gv = $cv->GV;
    return $gv->NAME;
}

=pod

=head1 SYNOPSIS

Test all methods for C<CAF::TextRender>

=cut

my $contents = {
    'name_level0' => 'value_level0',
    'level1' => {
        'name_level1' => 'value_level1',
    }
};

my $rnd;

$rnd = CAF::TextRender->new('something', $contents);
isa_ok ($rnd, "CAF::TextRender", "Correct class after new method");
ok(!defined($rnd->error('something')), "Fake logger initialised");

$rnd = CAF::TextRender->new('not_a_reserved_module', $contents);
isa_ok ($rnd, "CAF::TextRender", "Correct class after new method");
is(get_name($rnd->{method}), "tt", "fallback/default render method tt selected");

is($rnd->{includepath}, '/usr/share/templates/quattor', 'Default template base');
is($rnd->{relpath}, 'metaconfig', 'Default template relpath');

$rnd = CAF::TextRender->new('test', $contents,
                            includepath => getcwd()."/src/test/resources",
                            relpath => 'rendertest',
                            );
my $sane_tpl = $rnd->sanitize_template();
is($sane_tpl, "rendertest/test.tt", "correct TT file with relpath prefixed");

my $tpl = CAF::TextRender::get_template_instance($rnd->{includepath});
isa_ok ($tpl, "Template", "Returns Template instance");

my $res;
$res = <<EOF;
L0 value_level0
L1 name_level1 VALUE value_level1
EOF

=pod

=head2 Validate the test.tt itself

Test the unittest test.tt (if this test fails, the test itself is broken)

=cut

my $str;
ok($tpl->process($sane_tpl, $contents, \$str, "Generation of test.tt")) or diag("Failed generation of test.tt TT error: " . $tpl->error(),
    "Test TT verified");
is($str, $res, "test.tt rendered contents correctly (test.tt is ok)");

=pod 

=head2 Test tt method

Test the CAF::TextRender tt call

=cut

is($rnd->tt(), $res, "test.tt rendered contents correctly");


=pod

=head2 Test render text

Test rendering the text and stringification overload

=cut

is($rnd->get_text(), $res, "stringification successful");
is("$rnd", $res, "stringification overload successful");

=pod 

=head2 Test cache

Test the get_text caching by modifying the internal cache directly.

=cut

ok(exists($rnd->{_cache}), "Cache exists");
is($rnd->{_cache}, $res, "Latests result is cached");

my $modified = "NOCACHE";
# never ever do this in the code itself.
$rnd->{_cache} = $modified;
is($rnd->get_text(), $modified, "Cache is used (returning the content of _cache rather then the rendered text)");
is($rnd->get_text(1), $res, "Cache is cleared (returning re-rendered text)");
is($rnd->{_cache}, $res, "Latests result is cached again.");

my $nocachernd = CAF::TextRender->new('test', $contents,
                                      includepath => getcwd()."/src/test/resources",
                                      relpath => 'rendertest',
                                      usecache => 0,
                                      );
isa_ok ($nocachernd, "CAF::TextRender", "Correct class after new method (no cache)");
is($nocachernd->get_text(), $res, "No cache rendering successful");
ok(! exists($nocachernd->{_cache}), "No cache exists");

=pod

=head2 Test render failure

Test failing render (stringification returns undef).

=cut

ok(defined("$rnd"), "render succes, stringification returns something defined");

my $brokenrnd = CAF::TextRender->new('test_broken', $contents,
                                      includepath => getcwd()."/src/test/resources",
                                      relpath => 'rendertest',
                                      );
isa_ok ($brokenrnd, "CAF::TextRender", "Correct class after new method (but with broken TT)");
ok(! defined($brokenrnd->get_text()), "get_text returns undef, rendering failed");
is("$brokenrnd", "", "render failed, stringification returns empty string");

# not cached
ok(!exists($brokenrnd->{_cache}), "Render failed, no caching of the event. (Failure will be recreated)");

=pod

=head2 Test filehandle

Test filehandle options

=cut

my $fh = $rnd->filewriter("/some/name");
isa_ok($fh, "CAF::FileWriter", "CAF::TextRender fh method returns CAF::FileWriter");
is("$fh", $res, "File contents as expected");

my $header = "HEADER"; # no newline, check TODO
my $footer = "FOOTER"; # no newline, eol should add one
$fh = $rnd->filewriter("/some/name",
               header => $header,
               footer => $footer,
               );
isa_ok($fh, "CAF::FileWriter", "CAF::TextRender fh method returns CAF::FileWriter");
# add newline due to eol
is("$fh", $header.$res.$footer."\n", "File contents as expected");

# test undef returned on render failure
ok(! defined($brokenrnd->filewriter("/my/file")), "render failed, filewriter returns undef");


# force the internal module for testing purposes!
$rnd->{module} = '/my/abs/path';
ok(!defined($rnd->sanitize_template()), "module as template can't be absolute path");
$rnd->{module} = 'nottest';
ok(!defined($rnd->sanitize_template()), "no TT file nottest");

=pod

=head2 Test eol

Test end-of-line (eol)

=cut

$rnd = CAF::TextRender->new('noeol', $contents,
                            includepath => getcwd()."/src/test/resources",
                            relpath => 'rendertest',
                            eol => 0,
                            );
my $noeol = "noeol";
is("$rnd", $noeol, "noeol.tt rendered as expected");
unlike("$rnd", qr{\n$}, "No newline at end of rendered text");

$rnd = CAF::TextRender->new('noeol', $contents,
                            includepath => getcwd()."/src/test/resources",
                            relpath => 'rendertest',
                            );
is($rnd->{eol}, 1, "eol default to true");
is("$rnd", "$noeol\n", "noeol.tt with eol=1 rendered as expected");
like("$rnd", qr{\n$}, "Newline at end of rendered text (with eol=1)");

=pod

=head2 Reserved modules

Test the reserved modules

=head3 json

Test json/JSON::XS

=cut

$res = '{"level1":{"name_level1":"value_level1"},"name_level0":"value_level0"}';
$rnd = CAF::TextRender->new('json', $contents, eol=>0);
ok($rnd->load_module('JSON::XS'), "JSON::XS loaded");
is("$rnd", $res, "json module rendered correctly");

=pod

=head3 yaml

Test yaml/YAML::XS

=cut

$res = <<EOF;
---
level1:
  name_level1: value_level1
name_level0: value_level0
EOF
$rnd = CAF::TextRender->new('yaml', $contents);
ok($rnd->load_module('YAML::XS'), "YAML::XS loaded");
is("$rnd", $res, "yaml module rendered correctly");

=pod

=head3 properties

Test properties/Config::Properties

=cut

$res = <<EOF;

level1.name_level1=value_level1
name_level0=value_level0
EOF
$rnd = CAF::TextRender->new('properties', $contents);
ok($rnd->load_module('Config::Properties'), "Config::Properties loaded");
my ($line, @txt) = split("\n", "$rnd");
# first line is a header with timestamp.
like($line, qr{^#\s.*$}, "Start with header (contains timestamp)");
# add extra newline
is(join("\n", @txt,''), $res, "properties module rendered correctly");

=pod

=head3 tiny

Test tiny/Config::Tiny

=cut

$res = <<EOF;
name_level0=value_level0

[level1]
name_level1=value_level1
EOF
$rnd = CAF::TextRender->new('tiny', $contents);
ok($rnd->load_module('Config::Tiny'), "Config::Tiny loaded");
is("$rnd", $res, "tiny module rendered correctly");

=pod

=head3 general

Test general/Config::General

=cut

$res = <<EOF;
<level1>
    name_level1   value_level1
</level1>
name_level0   value_level0
EOF
$rnd = CAF::TextRender->new('general', $contents);
ok($rnd->load_module('Config::General'), "Config::General loaded");
is("$rnd", $res, "general module rendered correctly");

done_testing();
