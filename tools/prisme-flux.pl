#!/usr/bin/perl
# prisme : qualité de chaque flux SANS l'ouvrir. On demande au serveur la fiche technique qu'il a déjà
# (player_api.php ?action=get_vod_info / get_series_info : vidéo, audio, débit, durée, conteneur).
# Ce sont des requêtes d'information, comme la liste des films : aucune lecture de flux, donc aucune
# connexion de lecture utilisée. Les requêtes sont envoyées doucement (4 à la fois, avec des pauses)
# et gardées en cache : la fois suivante, seuls les nouveaux films sont demandés.
use strict; use warnings; use utf8; use JSON::PP; use File::Temp qw(tempdir); use File::Path qw(make_path);
binmode(STDOUT, ":utf8");
my ($dir) = @ARGV; my ($U, $N, $P) = @ENV{qw(PRISME_U PRISME_N PRISME_P)};
die "Dossier manquant\n" unless $dir && -d $dir; die "Identifiants manquants\n" unless $U && defined $N && defined $P;
my $MAXV = $ENV{PRISME_MAXV} || 4000; my $MAXS = $ENV{PRISME_MAXS} || 800;
my $J = JSON::PP->new->utf8->canonical; my $tmp = tempdir(CLEANUP => 1);
(my $host = $U) =~ s{^https?://}{}; $host =~ s/[^A-Za-z0-9]+/-/g;
my $CACHE = "$ENV{HOME}/Library/Caches/prisme-flux/$host"; make_path("$CACHE/v", "$CACHE/s");
sub slurp { my ($f) = @_; open(my $h, "<:raw", $f) or return ""; local $/; my $d = <$h>; close $h; return defined $d ? $d : "" }
sub enc { my ($s) = @_; utf8::encode($s) if utf8::is_utf8($s); $s =~ s/([^A-Za-z0-9\-_.~])/sprintf("%%%02X", ord $1)/ge; return $s }
my $auth = "username=" . enc($N) . "&password=" . enc($P);
# 4 requêtes à la fois, 150 par vague, une pause entre les vagues : le serveur n'est jamais bousculé
sub fetch_api { my ($list) = @_; my $i = 0;
  while ($i < @$list) { my @b = @$list[$i .. ($i + 149 < $#$list ? $i + 149 : $#$list)]; $i += 150;
    my $cfg = "$tmp/c" . int(rand(1e9)); open(my $c, ">", $cfg) or die; for (@b) { print $c "url = \"$U/player_api.php?$auth&$_->[0]\"\noutput = \"$_->[1]\"\n" } close $c;
    system("curl", "-sSL", "--compressed", "--max-time", "20", "--retry", "1", "-A", "Mozilla/5.0", "--parallel", "--parallel-max", "4", "-K", $cfg); unlink $cfg;
    printf "\r  %d / %d", ($i < @$list ? $i : scalar @$list), scalar @$list; sleep 1 if $i < @$list }
  print "\n" if @$list }
# fiche technique ffprobe du serveur → résumé compact
sub probe { my ($inf) = @_; return undef unless ref $inf eq "HASH"; my $v = ref $inf->{video} eq "HASH" ? $inf->{video} : {}; my $a = ref $inf->{audio} eq "HASH" ? $inf->{audio} : {};
  return undef unless $v->{codec_name} || $v->{height} || $a->{codec_name};
  my $fr = $v->{avg_frame_rate} || $v->{r_frame_rate} || ""; my $fps = $fr =~ m{^(\d+)/(\d+)$} && $2 ? sprintf("%.3g", $1 / $2) + 0 : 0;
  my $tr = $v->{color_transfer} // ""; my $tag = lc($v->{codec_tag_string} // "") . " " . ($v->{profile} // "");
  my $hdr = $tag =~ /dvh[e1]|dolby ?vision/i ? "DV" : $tr eq "smpte2084" ? "HDR10" : $tr eq "arib-std-b67" ? "HLG" : "";
  my ($lang, $ttl) = ("", ""); for my $t ($a->{tags}, $v->{tags}) { next unless ref $t eq "HASH"; $lang ||= $t->{language} // $t->{LANGUAGE} // ""; $ttl ||= $t->{title} // $t->{handler_name} // "" }
  # doublage : québécois (VFQ) ou de France (VFF) quand la piste le dit (langue fr-CA ou titre de piste)
  $lang = "frq" if $lang =~ /^fr.?ca$/i || $ttl =~ /\bvfq\b|qu[ée]b|canad/i; $lang = "frf" if $lang !~ /^frq$/ && ($lang =~ /^fr.?fr$/i || $ttl =~ /\bvff\b|truefrench|france/i);
  my $ap = $a->{profile} // ""; my $dur = $inf->{duration_secs} || 0;
  return [($v->{width} || 0) + 0, ($v->{height} || 0) + 0, lc($v->{codec_name} // ""), $hdr, $fps, ($inf->{bitrate} || 0) + 0,
          lc($a->{codec_name} // ""), ($a->{channels} || 0) + 0, lc($lang), $dur + 0, ($ap =~ /atmos|joc/i ? 1 : 0)] }

# --- films : une fiche par flux (stream_id), en cache tant que le flux ne change pas ---
my $vs = eval { $J->decode(slurp("$dir/get_vod_streams.json")) }; $vs = [] unless ref $vs eq "ARRAY";
my @V = sort { ($b->{added} || 0) <=> ($a->{added} || 0) } grep { ref $_ eq "HASH" && $_->{stream_id} && ($_->{name} // "") !~ /adult|xxx|porn|\+ ?18|18 ?\+|erotic/i } @$vs;
@V = @V[0 .. $MAXV - 1] if @V > $MAXV;
my @need = grep { my $f = "$CACHE/v/$_->{stream_id}-" . ($_->{added} || 0) . ".json"; !-s $f } @V;
print "Fiches techniques des films : ", scalar(@V), " flux (", scalar(@V) - scalar(@need), " déjà en cache)…\n";
fetch_api([map { ["action=get_vod_info&vod_id=$_->{stream_id}", "$CACHE/v/$_->{stream_id}-" . ($_->{added} || 0) . ".json"] } @need]);
my (%VOD, $nv); for my $x (@V) { my $d = eval { $J->decode(slurp("$CACHE/v/$x->{stream_id}-" . ($x->{added} || 0) . ".json")) } || {};
  my $p = probe($d->{info}); next unless $p; push @$p, $x->{container_extension} // ""; $VOD{$x->{stream_id}} = $p; $nv++ }

# --- séries : la fiche du 1er épisode de chaque série (même format), et le nombre d'épisodes ---
my $ss = eval { $J->decode(slurp("$dir/get_series.json")) }; $ss = [] unless ref $ss eq "ARRAY";
my @Sx = sort { ($b->{last_modified} || 0) <=> ($a->{last_modified} || 0) } grep { ref $_ eq "HASH" && $_->{series_id} && ($_->{name} // "") !~ /adult|xxx|porn/i } @$ss;
@Sx = @Sx[0 .. $MAXS - 1] if @Sx > $MAXS;
my @sneed = grep { !-s "$CACHE/s/$_->{series_id}-" . ($_->{last_modified} || 0) . ".json" } @Sx;
print "Fiches techniques des séries : ", scalar(@Sx), " séries (", scalar(@Sx) - scalar(@sneed), " déjà en cache)…\n";
fetch_api([map { ["action=get_series_info&series_id=$_->{series_id}", "$CACHE/s/$_->{series_id}-" . ($_->{last_modified} || 0) . ".json"] } @sneed]);
my (%SER, $ns); for my $x (@Sx) { my $d = eval { $J->decode(slurp("$CACHE/s/$x->{series_id}-" . ($x->{last_modified} || 0) . ".json")) } || {};
  my $eps = ref $d->{episodes} eq "HASH" ? $d->{episodes} : {}; my @all = map { ref $_ eq "ARRAY" ? @$_ : () } values %$eps; next unless @all;
  my ($first) = grep { probe($_->{info}) } @all; next unless $first; my $p = probe($first->{info}); push @$p, $first->{container_extension} // "", scalar(@all);
  $SER{substr("" . ($x->{name} // ""), 0, 70)} = $p; $ns++ }

open(my $o, ">:raw", "$dir/flux.json") or die "Impossible d'écrire $dir/flux.json\n"; print $o $J->encode({ v => 1, at => time, vod => \%VOD, ser => \%SER }); close $o;
printf "✓ flux.json : qualité connue pour %d flux de films et %d séries, sans ouvrir aucun flux.\n", $nv || 0, $ns || 0;
