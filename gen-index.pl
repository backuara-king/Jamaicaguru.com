#!/usr/bin/perl
# Rebuilds index.html's 9 embedded <script type="text/plain" id="doc-*">
# blocks from the current source view files, leaving everything else in
# index.html (the shell: styles, iframes, router/analytics scripts) untouched.
#
# Deliberately does NOT use hardcoded line numbers to find where the doc-*
# blocks start/end in the existing index.html — it scans for the actual
# <script type="text/plain" id="doc-..."> lines instead. That line range
# shifts every time the surrounding shell markup/CSS/JS gains or loses a
# line, and a hardcoded-line-number version of this script silently
# corrupted index.html the first time that happened (some iframes lost,
# some doc-* blocks duplicated) — this version can't drift out of sync
# with the file it's editing.
#
# Run after editing any of the 9 source view files below, or after editing
# index.html's own shell (styles/router/analytics) directly. Also run
# gen-packages.pl first if pkg-template.html changed, since package-*.html
# are themselves generated from it.
#
# Usage: perl gen-index.pl

use strict;
use warnings;

my @ids   = qw(home 3day 5day 7day reviews addons addon-detail review checkout);
my @files = qw(home.html package-3day.html package-5day.html package-7day.html
               reviews-page.html addons-page.html addon-detail.html review.html checkout.html);

my $index_path = 'index.html';

open(my $in, '<:raw', $index_path) or die "Can't read $index_path: $!";
my @lines = <$in>;
close $in;

# Find every line that opens a doc-* block. Requires all 9 to be present,
# contiguous, and in the expected order — if that's ever not true, stop
# rather than guess at a range to replace.
my @doc_line_idx;
for my $i (0 .. $#lines) {
    push @doc_line_idx, $i if $lines[$i] =~ /^<script type="text\/plain" id="doc-/;
}
die "Expected 9 doc-* lines in $index_path, found " . scalar(@doc_line_idx) . "\n"
    unless @doc_line_idx == 9;
for my $i (1 .. $#doc_line_idx) {
    die "doc-* lines aren't contiguous (gap before index $doc_line_idx[$i]) — aborting, not guessing\n"
        unless $doc_line_idx[$i] == $doc_line_idx[$i - 1] + 1;
}
my $first = $doc_line_idx[0];
my $last  = $doc_line_idx[-1];
for my $i (0 .. 8) {
    die "doc-* block $first+$i is id=\"doc-$ids[$i]\"? expected doc-$ids[$i] at position $i\n"
        unless $lines[$first + $i] =~ /^<script type="text\/plain" id="doc-\Q$ids[$i]\E">/;
}

my @new_doc_lines;
for my $i (0 .. $#ids) {
    my $file = $files[$i];
    open(my $fh, '<:raw', $file) or die "Can't read $file: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    my $b64 = encode_base64_no_wrap($content);
    push @new_doc_lines, "<script type=\"text/plain\" id=\"doc-$ids[$i]\">$b64</script>\n";
}

splice(@lines, $first, $last - $first + 1, @new_doc_lines);

open(my $out, '>:raw', $index_path) or die "Can't write $index_path: $!";
print $out @lines;
close $out;

print "Rebuilt index.html (" . scalar(@ids) . " views embedded)\n";

# Minimal dependency-free base64 encoder (no wrapping) — avoids requiring
# MIME::Base64 to be installed; output must be one line with no line breaks,
# since the JS decoder (jgDecode in index.html) reads the whole element's
# textContent as one base64 string.
sub encode_base64_no_wrap {
    my ($data) = @_;
    my @tbl = ('A'..'Z','a'..'z','0'..'9','+','/');
    my $out = '';
    my $len = length($data);
    for (my $i = 0; $i < $len; $i += 3) {
        my $chunk = substr($data, $i, 3);
        my $n = length($chunk);
        my $b0 = ord(substr($chunk, 0, 1));
        my $b1 = $n > 1 ? ord(substr($chunk, 1, 1)) : 0;
        my $b2 = $n > 2 ? ord(substr($chunk, 2, 1)) : 0;
        my $triple = ($b0 << 16) | ($b1 << 8) | $b2;
        $out .= $tbl[($triple >> 18) & 0x3F];
        $out .= $tbl[($triple >> 12) & 0x3F];
        $out .= $n > 1 ? $tbl[($triple >> 6) & 0x3F] : '=';
        $out .= $n > 2 ? $tbl[$triple & 0x3F] : '=';
    }
    return $out;
}
