#!/usr/bin/perl
# prisme : fiches séries enrichies avec TMDB (affiches, grandes images, résumé, casting, chaîne, note).
# Si TMDB ne connaît pas une série, on prend l'affiche fournie par le fournisseur (champ « cover »).
# Écrit series.json dans chaque dossier prisme-* du Bureau. Un cache évite de tout retélécharger.
use strict; use warnings; use utf8; use JSON::PP; use MIME::Base64; use File::Temp qw(tempdir); use File::Path qw(make_path);
binmode(STDOUT, ":utf8");
my $TMDB = $ENV{PRISME_TMDB} || "https://api.themoviedb.org/3";
my $IMGB = $ENV{PRISME_TMDB_IMG} || "https://image.tmdb.org/t/p";
my $MAXS = $ENV{PRISME_MAXS} || 1500;   # séries traitées (les plus récentes d'abord, comme le simulateur)
my $MAXB = $ENV{PRISME_MAXB} || 200;    # grandes images de fond (les plus récentes)
my $MAXE = $ENV{PRISME_MAXE} || 800;    # séries dont on récupère les titres et résumés d'épisodes (les plus récentes)
my $TTL = 7 * 86400;
my @dirs = grep { -d $_ } glob("$ENV{HOME}/Desktop/prisme-*");
die "Aucun dossier prisme-... sur le Bureau. Lance d'abord la commande des données.\n" unless @dirs;
print "Clé API TMDB (elle ne s'affiche pas quand tu tapes) : ";
system("stty", "-echo"); my $key = <STDIN>; system("stty", "echo"); print "\n";
$key = "" unless defined $key; $key =~ s/\s+//g;
die "Aucune clé saisie.\n" unless length $key;
my @auth = length($key) > 40 ? ("-H", "Authorization: Bearer $key") : ();
my $akey = length($key) > 40 ? "" : "&api_key=$key";
my $tmp = tempdir(CLEANUP => 1);
my $CACHE = "$ENV{HOME}/Library/Caches/prisme-series"; make_path("$CACHE/d", "$CACHE/i");
my $J = JSON::PP->new->utf8->canonical;
my $hasSips = (-x "/usr/bin/sips") ? 1 : 0;

sub slurp { my ($f) = @_; open(my $h, "<:raw", $f) or return ""; local $/; my $d = <$h>; close $h; return defined $d ? $d : "" }
sub enc { my ($s) = @_; utf8::encode($s) if utf8::is_utf8($s); $s =~ s/([^A-Za-z0-9\-_.~])/sprintf("%%%02X", ord $1)/ge; return $s }
sub fetch_many { my ($list, @h) = @_; return unless @$list;
  my $cfg = "$tmp/cfg" . int(rand(1e9)); open(my $c, ">:utf8", $cfg) or die; for my $u (@$list) { my ($url, $f) = @$u; $url =~ s/"/%22/g; print $c "url = \"$url\"\noutput = \"$f\"\n" } close $c;
  system("curl", "-sSL", "--compressed", "--max-time", "25", "--retry", "2", "-A", "Mozilla/5.0", "--parallel", "--parallel-max", "12", @h, "-K", $cfg) }
sub jpeg { my ($f, $w, $q) = @_; return unless -s $f && $hasSips; my $o = "$f.jpg";
  system("/usr/bin/sips -s format jpeg -s formatOptions $q -Z $w '$f' --out '$o' >/dev/null 2>&1"); rename($o, $f) if -s $o }
sub datauri { my ($f) = @_; return undef unless -s $f; my $d = slurp($f);
  my $m = substr($d, 0, 2) eq "\xff\xd8" ? "image/jpeg" : substr($d, 0, 4) eq "\x89PNG" ? "image/png" : substr($d, 0, 4) eq "RIFF" ? "image/webp" : undef;
  return $m ? "data:$m;base64," . encode_base64($d, "") : undef }
# même nettoyage des titres que le simulateur (RI.base / RI.title)
sub base { my ($s) = @_; $s = "" unless defined $s;
  $s =~ s/^\s*([\[(|]?\s*(fr|fra|france|be|ch|ca|qc)\s*[\])|:\-–]+\s*)+//i;
  $s =~ s/[ᴴᴰᶠᵁ⁴ᴷˢ]+/ /g;
  $s =~ s/\b(4k|uhd|fhd|full ?hd|hd|sd|hevc|h\.?26[45]|x26[45]|1080p?|720p?|2160p?|hdr10?|dolby ?vision|50 ?fps|raw|backup|vip|multi|vostfr|vff|vf|truefrench|french)\b/ /gi;
  $s =~ s/[\[\]()|]+/ /g; $s =~ s/\s*[-–:]\s*$//; $s =~ s/^\s*[-–:]\s*//; $s =~ s/\s{2,}/ /g; $s =~ s/^\s+|\s+$//g; return $s }
my $TRAIL = qr/(?:^|[\s\-–:_.,|])(?:vost(?:-?fr)?|vostfr|vo|vf2?|vff|vfq|vfi|stfr|subfrench|truefrench|french|multi|eng|subs?|hdlight|hdr10\+?|hdr|dv|dolby ?vision|imax|3d|remux|web(?:-?dl|rip)?|blu-?ray|bdrip|brrip|dvdrip|x26[45]|h\.?26[45]|hevc|10 ?bits?|atmos|dts|ac3|aac|5\.1|7\.1|extended|uncut|remastered|director'?s ?cut|version longue|4k|uhd|fhd|hd|sd|1080[pi]?|720p?|2160p?|19[2-9]\d|20[0-3]\d)[\s\-–:_.,|]*$/i;
sub title { my ($n) = @_; my $s = base($n); while (1) { my $t = $s; $t =~ s/$TRAIL//; $t =~ s/\s*[-–:|,]\s*$//; $t =~ s/^\s+|\s+$//g; last if length($t) < 2 || $t eq $s; $s = $t } return $s }
sub year { my ($n) = @_; return ($n || "") =~ /\b(19[2-9]\d|20[0-3]\d)\b/ ? $1 : 0 }
sub simp { my ($s) = @_; $s = lc($s // ""); $s =~ tr/àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ/aaaaaaceeeeiiiinooooouuuuyyoa/; $s =~ s/[^a-z0-9]+//g; return $s }
my $ADULT = qr/adult|xxx|porn|\+ ?18|18 ?\+|for adults|erotic|\bsex|\bhot\b/i;
my $FR = qr/(^|[^a-z])(fr|fra|france|french|vf|vff|vostfr|truefrench)([^a-z]|$)/i;

# --- vérifie la clé ---
my $chk = "$tmp/chk.json"; fetch_many([["$TMDB/configuration?x=1$akey", $chk]], @auth);
my $cj = eval { $J->decode(slurp($chk)) } || {};
die "TMDB refuse cette clé (" . ($cj->{status_message} || "réponse illisible") . "). Vérifie-la sur themoviedb.org > Paramètres > API.\n" if !$cj->{images};
print "✓ Clé TMDB acceptée\n";
my $now = time;

for my $dir (@dirs) {
  print "== $dir\n";
  my $ss = eval { $J->decode(slurp("$dir/get_series.json")) }; $ss = [] unless ref $ss eq "ARRAY";
  unless (@$ss) { print "Pas de séries dans ce dossier (get_series.json vide ou absent).\n"; next }
  # --- mêmes catégories que le simulateur : françaises si le fournisseur en a, jamais adultes ---
  my $cs = eval { $J->decode(slurp("$dir/get_series_categories.json")) }; $cs = [] unless ref $cs eq "ARRAY";
  my @call = grep { ref $_ eq "HASH" && ($_->{category_name} // "") !~ $ADULT } @$cs; my @cfr = grep { ($_->{category_name} // "") =~ $FR } @call;
  my %okc = map { ("" . ($_->{category_id} // "")) => 1 } (@cfr ? @cfr : @call);
  my $frOnly = !%okc && grep { ref $_ eq "HASH" && ($_->{name} // "") =~ $FR } @$ss;
  my (%grp, @order);
  for my $x (@$ss) { next unless ref $x eq "HASH"; my $nm = "" . ($x->{name} // ""); next if $nm eq "" || $nm =~ $ADULT;
    next if %okc && !$okc{"" . ($x->{category_id} // "")}; next if $frOnly && $nm !~ $FR;
    my $t = title($nm); next if length($t) < 2; my $k = simp($t); next if $k eq "";
    my $tm = $x->{tmdb} // $x->{tmdb_id} // ""; $tm = "" unless $tm =~ /^\d+$/ && $tm > 0;
    my $g = $grp{$k} //= do { push @order, $k; +{ t => $t, y => year($x->{releaseDate} // $x->{release_date} // "") || year($nm), tm => $tm, a => 0, names => [], cover => "", bdp => "" } };
    $g->{tm} = $tm if $g->{tm} eq "" && $tm ne ""; my $a = $x->{last_modified} // 0; $g->{a} = $a if $a =~ /^\d+$/ && $a > $g->{a};
    my $cv = $x->{cover} // ""; $g->{cover} ||= $cv if $cv =~ m{^https?://};
    my $bp = ref $x->{backdrop_path} eq "ARRAY" ? ($x->{backdrop_path}[0] // "") : ""; $g->{bdp} ||= $bp if $bp =~ m{^https?://};
    push @{ $g->{names} }, substr($nm, 0, 70) }
  my @G = sort { $b->{a} <=> $a->{a} } map { $grp{$_} } @order; @G = @G[0 .. $MAXS - 1] if @G > $MAXS;
  printf "%d séries distinctes chez ce fournisseur, %d traitées (les plus récentes)\n", scalar(@order), scalar(@G);
  # --- recherche TMDB pour celles sans identifiant ---
  my @q = grep { $_->{tm} eq "" } @G; my $i = 0;
  if (@q) { print "Recherche TMDB par titre : ", scalar(@q), " séries…\n";
    fetch_many([map { $i++; $_->{qf} = "$tmp/s$i.json"; ["$TMDB/search/tv?query=" . enc($_->{t}) . ($_->{y} ? "&first_air_date_year=$_->{y}" : "") . "&language=fr-FR&include_adult=false$akey", $_->{qf}] } @q], @auth);
    # sans résultat avec l'année, on réessaie sans l'année
    my @q2 = grep { my $r = eval { $J->decode(slurp($_->{qf})) } || {}; $_->{y} && !@{ $r->{results} || [] } } @q;
    fetch_many([map { ["$TMDB/search/tv?query=" . enc($_->{t}) . "&language=fr-FR&include_adult=false$akey", $_->{qf}] } @q2], @auth) if @q2;
    for my $g (@q) { my $r = eval { $J->decode(slurp($g->{qf})) } || {}; my $w = simp($g->{t});
      for my $m (@{ $r->{results} || [] }) { my $ok = grep { simp($_) eq $w || (length($w) >= 5 && index(simp($_), $w) == 0) } grep { defined } ($m->{name}, $m->{original_name});
        if ($ok) { $g->{tm} = "" . $m->{id}; last } }
      $g->{tm} = "" . $r->{results}[0]{id} if $g->{tm} eq "" && $r->{results} && @{ $r->{results} } == 1 } }
  my @ok = grep { $_->{tm} ne "" } @G;
  printf "Séries reconnues sur TMDB : %d / %d\n", scalar(@ok), scalar(@G);
  # --- fiches détaillées (cache 7 jours) ---
  my %need; for my $g (@ok) { my $f = "$CACHE/d/$g->{tm}.json"; $need{$g->{tm}} = $f unless -s $f && $now - (stat($f))[9] < $TTL }
  my %uid = map { $_->{tm} => 1 } @ok; print "Fiches à télécharger : ", scalar(keys %need), " (", scalar(keys %uid) - scalar(keys %need), " déjà en cache)…\n";
  fetch_many([map { ["$TMDB/tv/$_?language=fr-FR&append_to_response=aggregate_credits,content_ratings,videos&include_video_language=fr,en,null$akey", $need{$_}] } keys %need], @auth);
  my (%M, @imgs, %byName, %NL); my $rank = 0;
  for my $g (@G) { $rank++; my $k; my $d = $g->{tm} ne "" ? eval { $J->decode(slurp("$CACHE/d/$g->{tm}.json")) } : undef;
    if (ref $d eq "HASH" && $d->{id}) { $k = "t$d->{id}";
      unless ($M{$k}) {
        my @cast = map { [$_->{name}, ((($_->{roles} || [])->[0] || {})->{character} // "")] } grep { $_->{name} } @{ ($d->{aggregate_credits} || {})->{cast} || [] }; @cast = @cast[0 .. 7] if @cast > 8;
        my $age = ""; for my $r (@{ ($d->{content_ratings} || {})->{results} || [] }) { if (($r->{iso_3166_1} // "") eq "FR") { $age = $r->{rating} // ""; last } }
        my @vid = sort { $b->[0] <=> $a->[0] } map { my $v = $_; my $n = $v->{name} // ""; my $l = $v->{iso_639_1} // "";
          [($l eq "fr" ? 100 : $l eq "en" ? 10 : 0) + ($n =~ /vostf?r?|sous-titr/i ? -45 : 0) + ($n =~ /\bvf\b|version fran|en fran/i ? 25 : 0) + (($v->{type} // "") eq "Trailer" ? 10 : 0) + ($v->{official} ? 4 : 0), $v] }
          grep { ($_->{site} // "") eq "YouTube" && ($_->{type} // "") =~ /Trailer|Teaser/ } @{ ($d->{videos} || {})->{results} || [] };
        my $rt = $d->{episode_run_time} || []; my $ep = @$rt ? $rt->[0] + 0 : 0;
        $M{$k} = { t => $d->{name} // $g->{t}, ot => $d->{original_name} // "", y => (($d->{first_air_date} // "") =~ /^(\d{4})/ ? $1 + 0 : ($g->{y} || 0) + 0),
          g => [map { $_->{name} } @{ $d->{genres} || [] }], ov => $d->{overview} // "", age => $age, va => ($d->{vote_average} || 0) + 0, vc => ($d->{vote_count} || 0) + 0,
          net => ((($d->{networks} || [])->[0] || {})->{name} // ""), cr => join(", ", map { $_->{name} } grep { $_->{name} } @{ $d->{created_by} || [] }),
          ns => ($d->{number_of_seasons} || 0) + 0, ne => ($d->{number_of_episodes} || 0) + 0, st => $d->{status} // "", ep => $ep, cast => \@cast,
          yt => @vid ? $vid[0][1]{key} : "", ytl => !@vid ? "" : ($vid[0][1]{iso_639_1} // "") ne "fr" ? "vo" : ($vid[0][1]{name} // "") =~ /vostf?r?|sous-titr/i ? "vost" : "vf" };
        my $nw = ($d->{networks} || [])->[0]; if ($nw && $nw->{name} && $nw->{logo_path} && !$NL{$nw->{name}}) { (my $lp = $nw->{logo_path}) =~ s/\.svg$/.png/i; $NL{$nw->{name}} = ["$IMGB/w185$lp", "$CACHE/i/n$nw->{id}.png"] }
        my $po = $d->{poster_path}; my $bd = $d->{backdrop_path};
        if ($po) { push @imgs, ["$IMGB/w185$po", "$CACHE/i/p$d->{id}", 220, 60, $k, "po"] } elsif ($g->{cover}) { push @imgs, [$g->{cover}, "$CACHE/i/c" . simp($g->{t}), 220, 60, $k, "po"] }
        if ($bd && $rank <= $MAXB) { push @imgs, ["$IMGB/w780$bd", "$CACHE/i/b$d->{id}", 720, 55, $k, "bd"] } } }
    elsif ($g->{cover}) { # inconnue de TMDB : l'affiche du fournisseur
      $k = "c" . simp($g->{t}); $M{$k} //= { t => $g->{t}, y => ($g->{y} || 0) + 0 };
      push @imgs, [$g->{cover}, "$CACHE/i/c" . simp($g->{t}), 220, 60, $k, "po"];
      push @imgs, [$g->{bdp}, "$CACHE/i/cb" . simp($g->{t}), 720, 55, $k, "bd"] if $g->{bdp} && $rank <= $MAXB }
    next unless $k; $byName{$_} = $k for @{ $g->{names} } }
  # --- épisodes en français (titre, résumé, note, date de diffusion) : une requête par saison, cache 7 jours ---
  my (@sq, %seen2); my $er = 0;
  for my $g (@G) { next if $g->{tm} eq "" || $seen2{$g->{tm}}++; last if ++$er > $MAXE; my $d = eval { $J->decode(slurp("$CACHE/d/$g->{tm}.json")) }; next unless ref $d eq "HASH" && $d->{id};
    for my $sn (map { $_->{season_number} } grep { ($_->{season_number} // 0) > 0 } @{ $d->{seasons} || [] }) { my $f = "$CACHE/d/$d->{id}-s$sn.json";
      push @sq, [$d->{id}, $sn, $f, (-s $f && $now - (stat($f))[9] < $TTL) ? 0 : 1] } }
  my @sdl = grep { $_->[3] } @sq; print "Saisons (titres et résumés des épisodes) : ", scalar(@sq), " (", scalar(@sq) - scalar(@sdl), " déjà en cache)…\n";
  fetch_many([map { ["$TMDB/tv/$_->[0]/season/$_->[1]?language=fr-FR$akey", $_->[2]] } @sdl], @auth);
  my $nep = 0; for my $q (@sq) { my $k = "t$q->[0]"; next unless $M{$k}; my $sd = eval { $J->decode(slurp($q->[2])) }; next unless ref $sd eq "HASH";
    for my $e (@{ $sd->{episodes} || [] }) { my $en = $e->{episode_number} // 0; next unless $en > 0; my $nm = $e->{name} // ""; $nm = "" if $nm =~ /^([ée]pisode|ep\.?)\s*\d+$/i;
      my $ov = $e->{overview} // ""; $ov = substr($ov, 0, 300); next if $nm eq "" && $ov eq "" && !$e->{air_date};
      $M{$k}{eps}{"$q->[1]-$en"} = [$nm, $ov, ($e->{vote_count} || 0) >= 3 ? sprintf("%.1f", $e->{vote_average} || 0) + 0 : 0, $e->{air_date} // ""]; $nep++ } }
  print "Épisodes décrits par TMDB : $nep\n";
  # --- images (cache) ---
  my @dl = grep { !-s $_->[1] } @imgs; my %dlu; @dl = grep { !$dlu{$_->[1]}++ } @dl;
  print "Images à télécharger : ", scalar(@dl), " (", scalar(@imgs) - scalar(@dl), " en cache)…\n";
  fetch_many([map { [$_->[0], $_->[1]] } @dl]); jpeg($_->[1], $_->[2], $_->[3]) for @dl;
  for my $im (@imgs) { my $u = datauri($im->[1]); $M{$im->[4]}{$im->[5]} = $u if $u }
  # --- logos des chaînes et plateformes (PNG transparents, gardés tels quels) ---
  fetch_many([map { [$_->[0], $_->[1]] } grep { !-s $_->[1] } values %NL]);
  my %NLO; for my $n (keys %NL) { my $u = datauri($NL{$n}[1]); $NLO{$n} = $u if $u }
  # --- tendances en France cette semaine (séries chez ce fournisseur) ---
  my @pp = map { ["$TMDB/trending/tv/week?language=fr-FR&page=$_$akey", "$tmp/tr$_.json"] } 1 .. 3; fetch_many(\@pp, @auth);
  my @top; for my $p (@pp) { my $r = eval { $J->decode(slurp($p->[1])) } || {}; for my $m (@{ $r->{results} || [] }) { my $k = "t$m->{id}"; push @top, $k if $M{$k} && !grep { $_ eq $k } @top } }
  @top = @top[0 .. 9] if @top > 10;
  my $out = { v => 1, at => $now, names => \%byName, m => \%M, top => \@top, nl => \%NLO };
  open(my $o, ">:raw", "$dir/series.json") or die "Impossible d'écrire $dir/series.json\n"; print $o $J->encode($out); close $o;
  my $np = grep { $_->{po} } values %M; my $nb = grep { $_->{bd} } values %M; my $nt = grep { /^t/ } keys %M;
  printf "✓ series.json : %d séries (%d fiches TMDB), %d affiches, %d grandes images, %d logos de chaînes, top 10 : %d séries, %.1f Mo\n", scalar(keys %M), $nt, $np, $nb, scalar(keys %NLO), scalar(@top), (-s "$dir/series.json") / 1048576;
}
print "Terminé. Ajoute series.json dans le simulateur (bouton « Choisir les fichiers… »).\n";
system("open", $dirs[0]) if -x "/usr/bin/open";
