#!/usr/bin/perl
# prisme : récupère les affiches TMDB des programmes du jour et les logos des chaînes
# Lit les dossiers prisme-* du Bureau et écrit images.json dans chacun.
use strict; use warnings; use JSON::PP; use MIME::Base64; use Time::Local; use File::Temp qw(tempdir);
my $TMDB = $ENV{PRISME_TMDB} || "https://api.themoviedb.org/3";
my $IMGB = $ENV{PRISME_TMDB_IMG} || "https://image.tmdb.org/t/p";
my $MAXT = 300; my $MAXL = 600;
my @dirs = grep { -d $_ } glob("$ENV{HOME}/Desktop/prisme-*");
die "Aucun dossier prisme-... sur le Bureau. Lance d'abord la commande des données.\n" unless @dirs;
print "Clé API TMDB (elle ne s'affiche pas quand tu tapes) : ";
system("stty", "-echo"); my $key = <STDIN>; system("stty", "echo"); print "\n";
$key = "" unless defined $key; $key =~ s/\s+//g;
die "Aucune clé saisie.\n" unless length $key;
my @auth = length($key) > 40 ? ("-H", "Authorization: Bearer $key") : ();
my $akey = length($key) > 40 ? "" : "&api_key=$key";
my $tmp = tempdir(CLEANUP => 1);
my $J = JSON::PP->new->utf8->canonical;
my $hasSips = (-x "/usr/bin/sips") ? 1 : 0;

sub slurp { my ($f) = @_; open(my $h, "<:raw", $f) or return ""; local $/; my $d = <$h>; close $h; return defined $d ? $d : "" }
sub enc { my ($s) = @_; $s =~ s/([^A-Za-z0-9\-_.~])/sprintf("%%%02X", ord $1)/ge; return $s }
sub ent { my ($s) = @_; $s =~ s/<!\[CDATA\[(.*?)\]\]>/$1/gs; $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&(apos|#39);/'/g; $s =~ s/&amp;/&/g; $s =~ s/^\s+|\s+$//g; return $s }
sub tsec { my ($v) = @_; return undef unless $v && $v =~ /^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)?\s*([+-])?(\d\d)?(\d\d)?/;
  my $t = timegm($6 || 0, $5, $4, $3, $2 - 1, $1); if (defined $7) { my $o = ($8 * 60 + $9) * 60; $t -= ($7 eq "-" ? -$o : $o) } else { $t = timelocal($6 || 0, $5, $4, $3, $2 - 1, $1) } return $t }
sub simp { my ($s) = @_; $s = lc $s; $s =~ s/[^a-z0-9\x80-\xff]+//g; return $s }
sub clean { my ($t) = @_; $t =~ s/\s*[-:–]\s*(S\d+\s*E\d+|saison\s*\d+|[ée]pisode\s*\d+).*$//i; $t =~ s/\s*\([^)]*\)\s*$//; $t =~ s/\s*\|.*$//; $t =~ s/^\s+|\s+$//g; return $t }
sub fetch_many { # [[url, file], ...] en parallèle
  my ($list, @h) = @_; return unless @$list;
  my $cfg = "$tmp/cfg" . int(rand(1e9)); open(my $c, ">", $cfg) or die; for my $u (@$list) { my ($url, $f) = @$u; $url =~ s/"/%22/g; print $c "url = \"$url\"\noutput = \"$f\"\n" } close $c;
  system("curl", "-sSL", "--compressed", "--max-time", "20", "--retry", "1", "-A", "Mozilla/5.0", "--parallel", "--parallel-max", "12", @h, "-K", $cfg);
}
sub datauri { my ($f, $maxkb) = @_; return undef unless -s $f;
  if ($hasSips) { my $o = "$f.png"; system("/usr/bin/sips -s format png -Z 300 '$f' --out '$o' >/dev/null 2>&1"); $f = $o if -s $o }
  my $d = slurp($f); return undef if length($d) > $maxkb * 1024;
  my $m = substr($d, 0, 4) eq "\x89PNG" ? "image/png" : substr($d, 0, 2) eq "\xff\xd8" ? "image/jpeg" : substr($d, 0, 4) eq "RIFF" ? "image/webp" : substr($d, 0, 3) eq "GIF" ? "image/gif" : undef;
  return undef unless $m; return "data:$m;base64," . encode_base64($d, "") }

# --- vérifie la clé ---
my $chk = "$tmp/chk.json"; fetch_many([["$TMDB/configuration?x=1$akey", $chk]], @auth);
my $cj = eval { $J->decode(slurp($chk)) } || {};
die "TMDB refuse cette clé (" . ($cj->{status_message} || "réponse illisible") . "). Vérifie-la sur themoviedb.org > Paramètres > API.\n" if !$cj->{images};
print "✓ Clé TMDB acceptée\n";

my $now = time; my %done;
for my $dir (@dirs) {
  print "== $dir\n";
  my $x = slurp("$dir/xmltv.xml"); if (substr($x, 0, 2) eq "\x1f\x8b") { $x = `gunzip -c "$dir/xmltv.xml"` }
  my $ls = eval { $J->decode(slurp("$dir/get_live_streams.json")) }; $ls = [] unless ref $ls eq "ARRAY";
  # --- logos ---
  my %icon; while ($x =~ /<channel\b[^>]*\bid="([^"]*)"[^>]*>(.*?)<\/channel>/gs) { my ($id, $b) = ($1, $2); $icon{ent($id)} = ent($1) if $b =~ /<icon[^>]*\bsrc="([^"]*)"/ }
  my (@lg, %seenu); my $n = 0;
  for my $s (@$ls) { next unless ref $s eq "HASH"; my $e = defined $s->{epg_channel_id} ? "$s->{epg_channel_id}" : ""; my $u = ($e ne "" && $icon{$e}) || $s->{stream_icon} || ""; next unless $u =~ /^https?:/;
    next if $s->{name} && $s->{name} =~ /adult|xxx|porn|\+ ?18/i; $u =~ s/ /%20/g;
    my $f = $seenu{$u} //= do { $n++; "$tmp/l$n" }; my $nm = "" . ($s->{name} || ""); utf8::encode($nm) if utf8::is_utf8($nm); utf8::encode($e) if utf8::is_utf8($e); push @lg, [$e, $nm, $u, $f]; last if $n >= $MAXL }
  print "Logos des chaînes : ", scalar(keys %seenu), " à télécharger…\n";
  fetch_many([map { [$_, $seenu{$_}] } keys %seenu]);
  my (@logos, %lu); for my $l (@lg) { my $f = $l->[3]; $lu{$f} //= datauri($f, 120) // ""; push @logos, [$l->[0], $l->[1], $lu{$f}] if $lu{$f} ne "" }
  # --- programmes du jour ---
  my %tit; my $order = 0;
  while ($x =~ /<programme\b([^>]*)>(.*?)<\/programme>/gs) { my ($a, $b) = ($1, $2);
    my ($st) = $a =~ /\bstart="([^"]*)"/; my ($en) = $a =~ /\bstop="([^"]*)"/; my $s = tsec($st); my $e = tsec($en); next unless defined $s && defined $e;
    next if $e < $now - 3600 || $s > $now + 8 * 3600;
    my ($t) = $b =~ /<title[^>]*>(.*?)<\/title>/s; next unless defined $t; $t = ent($t); next if length($t) < 2;
    my @cat = $b =~ /<category[^>]*>(.*?)<\/category>/gs; my $cat = join(" ", map { ent($_) } @cat);
    next if $cat =~ /sport|foot|rugby|tennis|info|news|journal|m[ée]t[ée]o|magazine|jeu|game|t[ée]l[ée]achat|d[ée]bat|politique/i;
    next if $t =~ /^(journal|le journal|jt|m[ée]t[ée]o|info|infos|programme|fin des programmes|t[ée]l[ée]shopping|le 20h|le 13h|tirage)/i;
    my $c = clean($t); next if length($c) < 2;
    my $live = ($s <= $now && $e > $now) ? 0 : 1;
    $tit{$c} //= { t => $c, raw => {}, live => $live, ord => $order++, film => ($cat =~ /film|cin[ée]|t[ée]l[ée]film|movie/i ? 1 : 0) };
    $tit{$c}{raw}{$t} = 1; $tit{$c}{live} = 0 if !$live }
  my @T = sort { $a->{live} <=> $b->{live} || $a->{ord} <=> $b->{ord} } values %tit; @T = @T[0 .. $MAXT - 1] if @T > $MAXT;
  print "Programmes à rechercher sur TMDB : ", scalar(@T), "…\n";
  my $i = 0; fetch_many([map { $i++; $_->{q} = "$tmp/q$i.json"; ["$TMDB/search/multi?query=" . enc($_->{t}) . "&language=fr-FR&include_adult=false$akey", $_->{q}] } @T], @auth);
  my (@dl, %pf); my $k = 0;
  for my $p (@T) { my $r = eval { $J->decode(slurp($p->{q})) } || {}; my $want = simp($p->{t}); my $best;
    for my $m (@{ $r->{results} || [] }) { next unless ($m->{media_type} || "") =~ /^(movie|tv)$/; next unless $m->{backdrop_path} || $m->{poster_path};
      my @names = grep { defined } ($m->{title}, $m->{name}, $m->{original_title}, $m->{original_name});
      my $ok = grep { my $s = simp(do { my $z = $_; utf8::encode($z) if utf8::is_utf8($z); $z }); $s eq $want || (length($want) >= 6 && (index($s, $want) == 0 || index($want, $s) == 0) && length($s) >= 6) } @names;
      next unless $ok; $best = $m if !$best || ($p->{film} && $m->{media_type} eq "movie" && $best->{media_type} ne "movie"); last if $best && (!$p->{film} || $best->{media_type} eq "movie") }
    next unless $best; my $path = $best->{backdrop_path} ? "/w300$best->{backdrop_path}" : "/w185$best->{poster_path}";
    $k++; $p->{f} = "$tmp/p$k"; push @dl, ["$IMGB$path", $p->{f}] }
  print "Affiches trouvées : ", scalar(@dl), ", téléchargement…\n";
  fetch_many(\@dl);
  my %prog; for my $p (@T) { next unless $p->{f}; my $u = datauri($p->{f}, 160); next unless $u; $prog{$_} = $u for keys %{ $p->{raw} } }
  my $out = { v => 1, at => $now, logos => \@logos, progs => \%prog };
  open(my $o, ">:raw", "$dir/images.json") or die "Impossible d'écrire $dir/images.json\n"; print $o JSON::PP->new->canonical->encode($out); close $o;
  printf "✓ images.json : %d logos, %d affiches, %.1f Mo\n", scalar(@logos), scalar(keys %prog), (-s "$dir/images.json") / 1048576;
}
print "Terminé. Ajoute images.json dans le simulateur (bouton « Choisir les fichiers… »).\n";
system("open", $dirs[0]) if -x "/usr/bin/open";
