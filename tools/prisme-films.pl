#!/usr/bin/perl
# prisme : fiches films enrichies avec TMDB (mots-clés, équipe, recommandations, sagas,
# plateformes de streaming en France, bande-annonce, affiches). Écrit films.json dans
# chaque dossier prisme-* du Bureau. Un cache évite de tout retélécharger la fois suivante.
use strict; use warnings; use utf8; use JSON::PP; use MIME::Base64; use File::Temp qw(tempdir); use File::Path qw(make_path);
binmode(STDOUT, ":utf8");
my $TMDB = $ENV{PRISME_TMDB} || "https://api.themoviedb.org/3";
my $IMGB = $ENV{PRISME_TMDB_IMG} || "https://image.tmdb.org/t/p";
my $MAXF = $ENV{PRISME_MAXF} || 1500;   # films traités (les plus récents d'abord)
my $MAXB = $ENV{PRISME_MAXB} || 250;    # grandes images de fond (les plus récents)
my $TTL = 7 * 86400;                    # les fiches du cache sont rafraîchies après 7 jours
my @dirs = grep { -d $_ } glob("$ENV{HOME}/Desktop/prisme-*");
die "Aucun dossier prisme-... sur le Bureau. Lance d'abord la commande des données.\n" unless @dirs;
print "Clé API TMDB (elle ne s'affiche pas quand tu tapes) : ";
system("stty", "-echo"); my $key = <STDIN>; system("stty", "echo"); print "\n";
$key = "" unless defined $key; $key =~ s/\s+//g;
die "Aucune clé saisie.\n" unless length $key;
my @auth = length($key) > 40 ? ("-H", "Authorization: Bearer $key") : ();
my $akey = length($key) > 40 ? "" : "&api_key=$key";
my $tmp = tempdir(CLEANUP => 1);
my $CACHE = "$ENV{HOME}/Library/Caches/prisme-films"; make_path("$CACHE/d", "$CACHE/i");
my $J = JSON::PP->new->utf8->canonical;
my $hasSips = (-x "/usr/bin/sips") ? 1 : 0;

sub slurp { my ($f) = @_; open(my $h, "<:raw", $f) or return ""; local $/; my $d = <$h>; close $h; return defined $d ? $d : "" }
sub spew { my ($f, $d) = @_; open(my $h, ">:raw", $f) or return; print $h $d; close $h }
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
sub title { my ($n) = @_; my $s = base($n); $s =~ s/\(?\b(19[2-9]\d|20[0-3]\d)\b\)?\s*$//; $s =~ s/\s*[-–:]\s*$//; $s =~ s/^\s+|\s+$//g; return $s }
sub year { my ($n) = @_; return ($n || "") =~ /\b(19[2-9]\d|20[0-3]\d)\b/ ? $1 : 0 }
sub simp { my ($s) = @_; $s = lc($s // ""); $s =~ tr/àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ/aaaaaaceeeeiiiinooooouuuuyyoa/; $s =~ s/[^a-z0-9]+//g; return $s }

# --- vérifie la clé ---
my $chk = "$tmp/chk.json"; fetch_many([["$TMDB/configuration?x=1$akey", $chk]], @auth);
my $cj = eval { $J->decode(slurp($chk)) } || {};
die "TMDB refuse cette clé (" . ($cj->{status_message} || "réponse illisible") . "). Vérifie-la sur themoviedb.org > Paramètres > API.\n" if !$cj->{images};
print "✓ Clé TMDB acceptée\n";
my $now = time;

for my $dir (@dirs) {
  print "== $dir\n";
  my $vs = eval { $J->decode(slurp("$dir/get_vod_streams.json")) }; $vs = [] unless ref $vs eq "ARRAY";
  unless (@$vs) { print "Pas de films dans ce dossier (get_vod_streams.json vide ou absent).\n"; next }
  # --- regroupe les versions d'un même film ---
  my (%grp, @order);
  for my $x (@$vs) { next unless ref $x eq "HASH"; my $nm = "" . ($x->{name} // ""); next if $nm eq "";
    next if $nm =~ /adult|xxx|porn|\+ ?18|18 ?\+|for adults|erotic|\bsex|\bhot\b/i;
    my $t = title($nm); next if length($t) < 2; my $y = $x->{year} && $x->{year} =~ /^\d{4}$/ ? $x->{year} : year($nm);
    my $tm = $x->{tmdb} // $x->{tmdb_id} // ""; $tm = "" unless $tm =~ /^\d+$/ && $tm > 0;
    my $k = $tm ne "" ? "t$tm" : "q" . simp($t) . "#$y";
    my $g = $grp{$k} //= do { push @order, $k; +{ t => $t, y => $y, tm => $tm, a => 0, names => [], sids => [] } };
    $g->{tm} = $tm if $g->{tm} eq "" && $tm ne ""; my $a = $x->{added} // 0; $g->{a} = $a if $a =~ /^\d+$/ && $a > $g->{a};
    push @{ $g->{names} }, substr($nm, 0, 70); push @{ $g->{sids} }, "" . ($x->{stream_id} // "") }
  my @G = sort { $b->{a} <=> $a->{a} } map { $grp{$_} } @order; @G = @G[0 .. $MAXF - 1] if @G > $MAXF;
  printf "%d films distincts chez ce fournisseur, %d traités (les plus récents)\n", scalar(@order), scalar(@G);
  # --- recherche TMDB pour ceux sans identifiant ---
  my @q = grep { $_->{tm} eq "" } @G; my $i = 0;
  if (@q) { print "Recherche TMDB par titre : ", scalar(@q), " films…\n";
    fetch_many([map { $i++; $_->{qf} = "$tmp/s$i.json"; ["$TMDB/search/movie?query=" . enc($_->{t}) . ($_->{y} ? "&year=$_->{y}" : "") . "&language=fr-FR&include_adult=false$akey", $_->{qf}] } @q], @auth);
    for my $g (@q) { my $r = eval { $J->decode(slurp($g->{qf})) } || {}; my $w = simp($g->{t});
      for my $m (@{ $r->{results} || [] }) { my $ok = grep { simp($_) eq $w || (length($w) >= 5 && index(simp($_), $w) == 0) } grep { defined } ($m->{title}, $m->{original_title});
        if ($ok) { $g->{tm} = "" . $m->{id}; last } }
      $g->{tm} = "" . $r->{results}[0]{id} if $g->{tm} eq "" && $r->{results} && @{ $r->{results} } == 1 } }
  my @ok = grep { $_->{tm} ne "" } @G;
  printf "Films reconnus sur TMDB : %d / %d\n", scalar(@ok), scalar(@G);
  # --- fiches détaillées (cache 7 jours) ---
  my %need; for my $g (@ok) { my $f = "$CACHE/d/$g->{tm}.json"; $need{$g->{tm}} = $f unless -s $f && $now - (stat($f))[9] < $TTL }
  my %uid = map { $_->{tm} => 1 } @ok; print "Fiches à télécharger : ", scalar(keys %need), " (", scalar(keys %uid) - scalar(keys %need), " déjà en cache)…\n";
  fetch_many([map { ["$TMDB/movie/$_?language=fr-FR&append_to_response=keywords,credits,recommendations,videos,release_dates,watch/providers&include_video_language=fr,en,null$akey", $need{$_}] } keys %need], @auth);
  my (%M, @imgs); my $rank = 0;
  for my $g (@ok) { my $id = $g->{tm}; next if $M{$id}; my $d = eval { $J->decode(slurp("$CACHE/d/$id.json")) }; next unless ref $d eq "HASH" && $d->{id}; $rank++;
    my $cr = $d->{credits} || {}; my (@dir, $w, $mu, $ph);
    for my $c (@{ $cr->{crew} || [] }) { my $j = $c->{job} // ""; push @dir, $c->{name} if $j eq "Director"; $w //= $c->{name} if $j =~ /^(Screenplay|Writer)$/; $mu //= $c->{name} if $j eq "Original Music Composer"; $ph //= $c->{name} if $j eq "Director of Photography" }
    my @cast = map { [$_->{name}, $_->{character} // ""] } grep { $_->{name} } @{ $cr->{cast} || [] }; @cast = @cast[0 .. 7] if @cast > 8;
    my $age = ""; for my $r (@{ ($d->{release_dates} || {})->{results} || [] }) { next unless ($r->{iso_3166_1} // "") eq "FR"; for my $x (@{ $r->{release_dates} || [] }) { my $c = $x->{certification} // ""; if ($c ne "") { $age = $c; last } } }
    my $wp = (($d->{"watch/providers"} || {})->{results} || {})->{FR} || {}; my %W;
    for my $t (["f", "flatrate"], ["g", "free"], ["g", "ads"], ["r", "rent"], ["b", "buy"]) { push @{ $W{$t->[0]} }, map { $_->{provider_name} } @{ $wp->{$t->[1]} || [] } }
    my ($yt) = map { $_->{key} } sort { (($b->{iso_639_1} // "") eq "fr" ? 1 : 0) <=> (($a->{iso_639_1} // "") eq "fr" ? 1 : 0) } grep { ($_->{site} // "") eq "YouTube" && ($_->{type} // "") =~ /Trailer|Teaser/ } @{ ($d->{videos} || {})->{results} || [] };
    my $col = $d->{belongs_to_collection}; my $cid = $d->{imdb_id} // "";
    $M{$id} = { t => $d->{title}, ot => $d->{original_title}, y => (($d->{release_date} // "") =~ /^(\d{4})/ ? $1 + 0 : ($g->{y} || 0) + 0), d => ($d->{runtime} || 0) + 0,
      g => [map { $_->{name} } @{ $d->{genres} || [] }], ov => $d->{overview} // "", tg => $d->{tagline} // "", age => $age, va => ($d->{vote_average} || 0) + 0, vc => ($d->{vote_count} || 0) + 0,
      lang => $d->{original_language} // "", pays => join(", ", map { $_->{iso_3166_1} } @{ $d->{production_countries} || [] }),
      kw => [map { $_->{name} } @{ ($d->{keywords} || {})->{keywords} || [] }], dir => join(", ", @dir), w => $w // "", mu => $mu // "", ph => $ph // "",
      cast => \@cast, rec => [map { $_->{id} + 0 } @{ ($d->{recommendations} || {})->{results} || [] }], col => $col ? [$col->{id} + 0, $col->{name}] : undef,
      wp => \%W, yt => $yt // "", imdb => $cid };
    my $po = $d->{poster_path}; my $bd = $d->{backdrop_path};
    push @imgs, ["$IMGB/w185$po", "$CACHE/i/p$id", 220, 60, $id, "po"] if $po;
    push @imgs, ["$IMGB/w780$bd", "$CACHE/i/b$id", 720, 55, $id, "bd"] if $bd && $rank <= $MAXB }
  # --- affiches (cache) ---
  my @dl = grep { !-s $_->[1] } @imgs; print "Images à télécharger : ", scalar(@dl), " (", scalar(@imgs) - scalar(@dl), " en cache)…\n";
  fetch_many([map { [$_->[0], $_->[1]] } @dl]); jpeg($_->[1], $_->[2], $_->[3]) for @dl;
  for my $im (@imgs) { my $u = datauri($im->[1]); $M{$im->[4]}{$im->[5]} = $u if $u }
  my (%byName, %bySid); for my $g (@ok) { next unless $M{$g->{tm}}; $byName{$_} = $g->{tm} + 0 for @{ $g->{names} }; for (@{ $g->{sids} }) { $bySid{$_} = $g->{tm} + 0 if $_ ne "" } }
  my $out = { v => 1, at => $now, names => \%byName, sids => \%bySid, m => \%M };
  open(my $o, ">:raw", "$dir/films.json") or die "Impossible d'écrire $dir/films.json\n"; print $o $J->encode($out); close $o;
  my $np = grep { $_->{po} } values %M; my $nb = grep { $_->{bd} } values %M; my $ns = grep { @{ $_->{wp}{f} || [] } || @{ $_->{wp}{g} || [] } } values %M;
  printf "✓ films.json : %d fiches TMDB, %d affiches, %d grandes images, %d films disponibles aussi en streaming, %.1f Mo\n", scalar(keys %M), $np, $nb, $ns, (-s "$dir/films.json") / 1048576;
}
print "Terminé. Ajoute films.json dans le simulateur (bouton « Choisir les fichiers… »).\n";
system("open", $dirs[0]) if -x "/usr/bin/open";
