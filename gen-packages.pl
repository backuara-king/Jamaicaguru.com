#!/usr/bin/perl
use strict; use warnings;

my $dir = "C:\\Users\\Tray Emmanuel\\jamaica-guru-site";

sub slurp { my ($f) = @_; open(my $fh, "<", $f) or die "open $f: $!"; local $/; my $d = <$fh>; close $fh; return $d; }

my $poppins_faces   = slurp("/tmp/poppins-faces.txt"); # the 5 @font-face blocks (400-800), site-wide font
my $template        = slurp("$dir/pkg-template.html");

my $CHECK = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12l5 5L20 6"/></svg>';

sub included_li { my ($text) = @_; return "        <li>$CHECK $text</li>\n"; }

my @packages = (
  {
    file => "package-3day.html",
    VIEW_ID => "3day",
    PKG_BADGE => "Fan Favorite",
    PKG_NAME => "3-Day Mini Jamaican Adventure",
    PKG_TAGLINE => "Relax. Explore. Experience Jamaica.",
    PKG_HERO_DESC => "The perfect quick getaway. Enjoy handpicked experiences, comfortable stays, and private transportation as you explore the best of Jamaica in just 4 unforgettable days.",
    NIGHTS => 3, DAYS_TOTAL => 4, TRIP_LENGTH_LABEL => "3 nights, 4 days",
    PRICE_BASE => "820.00", PRICE_BASE_RAW => "820", PRICE_PER_GUEST_RAW => "180",
    HERO_CAP => 'Your escape <u>awaits</u>',
    PKG_ABOUT_TITLE => "Three days, three adventures, zero planning left for you to do",
    PKG_ABOUT_PARAGRAPHS =>
      "      <p>The 3-Day Mini Jamaican Adventure is built for travelers who want the best of Jamaica without spending their trip stitching together bookings. From the moment you land, a private driver has you covered &mdash; no rideshares, no haggling with taxis, no wondering how you&rsquo;ll get from the villa to the falls.</p>\n" .
      "      <p>You&rsquo;ll spend your days moving between three handpicked adventures, chosen from land, water, and open-air categories so the pace of the trip never feels one-note: a morning trail ride or canopy zip, an afternoon at Dunn&rsquo;s River Falls or the Blue Hole, and a third outing on an ATV, a jet ski, or a catamaran cruise, depending on what you pick during booking. Evenings are yours to relax at your accommodation, or opt into a night out at one of Ocho Rios&rsquo; clubs.</p>\n" .
      "      <p>Accommodation is arranged for three nights at a vetted 5-star Airbnb, with room for larger groups at checkout. Every guide, entry fee, and transfer tied to your selected adventures is already built into the package price &mdash; the only thing left to decide is which three experiences you want.</p>\n",
    INCLUDED_LIST =>
      included_li("3 nights accommodation for your full party") .
      included_li("Private transportation to and from every activity") .
      included_li("Entry fees and guides for all 3 chosen adventures") .
      included_li("Optional night life add-on, booked separately below") .
      included_li("24/7 support from your Jamaica Guru contact"),
    DEFAULT_DATE => "2026-09-14",
  },
  {
    file => "package-5day.html",
    VIEW_ID => "5day",
    PKG_BADGE => "Most Booked",
    PKG_NAME => "5-Day Getaway Jamaican Adventure",
    PKG_TAGLINE => "Waterfalls, beaches, and time to breathe.",
    PKG_HERO_DESC => "Six days on the ground with the same handled-for-you private transportation and curated adventures as our shorter trip &mdash; just with two extra nights to actually enjoy them.",
    NIGHTS => 5, DAYS_TOTAL => 6, TRIP_LENGTH_LABEL => "5 nights, 6 days",
    PRICE_BASE => "1,210.55", PRICE_BASE_RAW => "1210.55", PRICE_PER_GUEST_RAW => "260",
    HERO_CAP => 'Slow down. <u>Stay a while</u>.',
    PKG_ABOUT_TITLE => "Five nights, three adventures, and real time to slow down",
    PKG_ABOUT_PARAGRAPHS =>
      "      <p>The 5-Day Getaway Jamaican Adventure gives you the same handled-for-you booking as our shorter trip, with two extra nights to let the island set the pace. A private driver meets you at the airport and stays on call for the length of your stay &mdash; every excursion, every transfer, already arranged before you land.</p>\n" .
      "      <p>You&rsquo;ll pick three handpicked adventures across land, water, and open-air categories &mdash; think a canopy zipline, a climb up Dunn&rsquo;s River Falls, and an ATV run through the backcountry &mdash; but with five nights on the ground you&rsquo;ll have real downtime between them to explore Ocho Rios, cook at your Airbnb, or simply do nothing at all. Evenings are yours, with an optional night out built into booking if you want one.</p>\n" .
      "      <p>Accommodation is arranged for five nights at a vetted 5-star Airbnb, with room for larger groups at checkout. Every guide, entry fee, and transfer tied to your selected adventures is already built into the package price.</p>\n",
    INCLUDED_LIST =>
      included_li("5 nights accommodation for your full party") .
      included_li("Private transportation to and from every activity") .
      included_li("Entry fees and guides for all 3 chosen adventures") .
      included_li("Optional night life add-on, booked separately below") .
      included_li("24/7 support from your Jamaica Guru contact"),
    DEFAULT_DATE => "2026-09-21",
  },
  {
    file => "package-7day.html",
    VIEW_ID => "7day",
    PKG_BADGE => "Go All In",
    PKG_NAME => "7-Day Ultimate Jamaican Adventure",
    PKG_TAGLINE => "Every corner of the island, at your pace.",
    PKG_HERO_DESC => "Eight days to see the whole island &mdash; Seven Mile Beach, the Blue Mountains, and everywhere worth seeing in between &mdash; with nothing left for you to plan.",
    NIGHTS => 7, DAYS_TOTAL => 8, TRIP_LENGTH_LABEL => "7 nights, 8 days",
    PRICE_BASE => "1,450.00", PRICE_BASE_RAW => "1450", PRICE_PER_GUEST_RAW => "320",
    HERO_CAP => 'See it all, <u>unrushed</u>.',
    PKG_ABOUT_TITLE => "Seven nights, four adventures, and the whole island in between",
    PKG_ABOUT_PARAGRAPHS =>
      "      <p>The 7-Day Ultimate Jamaican Adventure is our longest package &mdash; built for travelers who want to see it all without spending a single day of their trip planning it. A private driver is on call from touchdown to takeoff, running you between accommodation and every adventure on your list.</p>\n" .
      "      <p>With a full week on the ground, you&rsquo;ll pick four handpicked adventures instead of three &mdash; one each from land, water, and open-air categories, plus a bonus fourth pulled from our most-requested add-ons, from a guided weed farm tour to Dolphin Cove. That&rsquo;s enough variety to fill a week without repeating a day. Evenings are yours to relax, or opt into a night out at one of Ocho Rios&rsquo; clubs.</p>\n" .
      "      <p>Accommodation is arranged for seven nights at a vetted 5-star Airbnb, with room for larger groups at checkout. Every guide, entry fee, and transfer tied to your four selected adventures is already built into the package price.</p>\n",
    INCLUDED_LIST =>
      included_li("7 nights accommodation for your full party") .
      included_li("Private transportation to and from every activity") .
      included_li("Entry fees and guides for all 4 chosen adventures") .
      included_li("Optional night life add-on, booked separately below") .
      included_li("24/7 support from your Jamaica Guru contact"),
    DEFAULT_DATE => "2026-10-05",
  },
);

for my $p (@packages) {
  my $out = $template;
  $out =~ s/\Q__POPPINS_FACES__\E/$poppins_faces/;
  for my $key (keys %$p) {
    next if $key eq 'file';
    my $val = $p->{$key};
    my $token = "{{$key}}";
    $out =~ s/\Q$token\E/$val/g;
  }
  # *_JS: escape single quotes/double quotes for safe JS string literals
  (my $pkg_name_js = $p->{PKG_NAME}) =~ s/(['"\\])/\\$1/g;
  $out =~ s/\Q{{PKG_NAME_JS}}\E/$pkg_name_js/g;
  (my $pkg_badge_js = $p->{PKG_BADGE}) =~ s/(['"\\])/\\$1/g;
  $out =~ s/\Q{{PKG_BADGE_JS}}\E/$pkg_badge_js/g;

  open(my $fh, ">", "$dir/$p->{file}") or die "write $p->{file}: $!";
  print $fh $out;
  close $fh;
  print "wrote $p->{file}\n";
}
