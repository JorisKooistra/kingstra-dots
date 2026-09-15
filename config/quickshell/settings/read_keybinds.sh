#!/usr/bin/env bash
# Read the explicit exec() entries from the Lua bind table. Loops and direct
# hl.bind() calls deliberately stay read-only: changing only their rendered
# result would be misleading and could break the Lua configuration.
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
bind_file="$config_dir/hypr/lua/binds.lua"

[[ -r "$bind_file" ]] || { printf '[]\n'; exit 0; }

perl -MJSON::PP - "$bind_file" <<'PERL'
use strict;
use warnings;

my $file = shift @ARGV;
open my $fh, '<', $file or die "Cannot read $file: $!";

my @bindings;
my %labels = (
    'kitty'                                      => 'Terminal',
    'nautilus'                                   => 'Bestandsbeheer',
    'quickshell-game'                            => 'Game launcher',
    'playerctl play-pause'                       => 'Media afspelen/pauzeren',
    'playerctl next'                             => 'Volgend nummer',
    'playerctl previous'                         => 'Vorig nummer',
    'hyprctl reload'                             => 'Hyprland herladen',
    'swayosd-client --output-volume raise'       => 'Volume omhoog',
    'swayosd-client --output-volume lower'       => 'Volume omlaag',
    'swayosd-client --output-volume mute-toggle' => 'Volume dempen',
);

my $line_no = 0;
while (my $line = <$fh>) {
    ++$line_no;
    chomp $line;

    # Supported forms:
    #   exec(mod .. " + T", scripts .. "/foo.sh")
    #   exec("Print", scripts .. "/screenshot.sh")
    #   exec(mod .. " + Q", "command", options)
    next unless $line =~ /^\s*exec\(\s*(?:(mod)\s*\.\.\s*)?"([^"]+)"\s*,\s*(.+)\)\s*$/;
    my ($uses_mod, $key_expr, $command_expr) = ($1, $2, $3);
    my $binding = $uses_mod ? "SUPER$key_expr" : $key_expr;
    $binding =~ s/^\s+|\s+$//g;

    my $command = '';
    if ($command_expr =~ /^"([^"]*)"\s*\.\.\s*scripts\s*\.\.\s*"([^"]+)"/) {
        $command = "$1~/.config/hypr/scripts$2";
    } elsif ($command_expr =~ /^scripts\s*\.\.\s*"([^"]+)"/) {
        $command = "~/.config/hypr/scripts$1";
    } elsif ($command_expr =~ /^"([^"]+)"/) {
        $command = $1;
    } else {
        # Expressions such as a concatenated command are intentionally not
        # made editable. They are still easy to find in binds.lua itself.
        next;
    }

    my @parts = split /\s*\+\s*/, $binding;
    my $key = pop @parts;
    next unless defined $key && length $key;
    my $mods = join(' + ', @parts);
    my $label = $labels{$command} // $command;
    $label =~ s{^(?:bash )?~/.config/hypr/scripts/}{ };
    $label =~ s{[-_]}{ }g;
    $label =~ s{\.sh(?:\s.*)?$}{};
    $label =~ s/^\s+|\s+$//g;
    $label = ucfirst($label) if length $label;

    push @bindings, {
        file => 'binds.lua', ln => $line_no, t => 'exec',
        mods => $mods, key => $key, d => 'exec', args => $command,
        label => $label, bound => JSON::PP::true, editable => JSON::PP::true,
    };
}

print encode_json(\@bindings), "\n";
PERL
