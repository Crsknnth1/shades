#!/usr/bin/perl
# Shades English: turns any PO catalog (e.g. `msgunfmt` of KDE's German one) into an
# English catalog where KDE says what Windows 11 says: "Recycle Bin" for Trash,
# "File Explorer" for Dolphin, "Personalize" for the desktop settings, and so on.
#
#   shades-english.pl <domain> < any.po > en_SH.po
#
# Every msgstr is rebuilt from its English msgid (and msgid_plural), then reworded.
# Exits 1 if no string needed rewording, so the caller can skip that catalog.
use strict;
use warnings;

my $domain = shift // '';

# Exact replacements for whole strings. "domain|text" applies in that domain only.
my %exact = (
    'Desktop and Wallpaper'                                     => 'Personalize',
    'Display Configuration'                                     => 'Display settings',
    'Open Terminal'                                             => 'Open in Terminal',
    'Create New'                                                => 'New',
    'Move to Trash'                                             => 'Delete',
    '&Move to Trash'                                            => '&Delete',
    'plasma_applet_org.kde.desktopcontainment|Icons'            => 'View',
    'plasma_applet_org.kde.desktopcontainment|&Refresh Desktop' => 'Refresh',
    'plasmashell|Show Panel Configuration'                      => 'Taskbar settings',
    # File Explorer's right-click menu.
    'dolphin|Copy Location'                                     => 'Copy as path',
    'dolphin|Add to Places'                                     => 'Pin to Quick access',
    'dolphin|Open Terminal Here'                                => 'Open in Terminal',
    'dolphin|Open in New Tab'                                   => 'Open in new tab',
    'dolphin|Open in New Window'                                => 'Open in new window',
    'dolphin|Sort By'                                           => 'Sort by',
    'dolphin|View Mode'                                         => 'View',
    'dolphin|Change View Mode'                                  => 'View',
    # File Explorer's navigation pane sections.
    'kio6|Places'                                               => 'Quick access',
    'kio6|Remote'                                               => 'Network',
    'kio6|Devices'                                              => 'This PC',
    # Taskbar button menus (Shades' taskbar is a copy of Plasma's task manager).
    'plasma_applet_org.shades.taskbar|&Pin to Task Manager'     => '&Pin to taskbar',
    'plasma_applet_org.shades.taskbar|Unpin from Task Manager'  => 'Unpin from taskbar',
    'plasma_applet_org.shades.taskbar|&Close'                   => '&Close window',
    'plasma_applet_org.shades.taskbar|&Close All'               => 'Close all windows',
    'plasma_applet_org.shades.taskbar|Places'                   => 'Pinned',
    'plasma_applet_org.shades.taskbar|Recent Files'             => 'Recent',
);

# Word-level replacements inside any string (applied in order).
my @words = (
    [qr/\bSystem Settings\b/, 'Settings'],
    [qr/\bDolphin\b/,         'File Explorer'],
    [qr/\bKonsole\b/,         'Terminal'],
    [qr/\bSystem Monitor\b/,  'Resource Monitor'],
    [qr/\bKWrite\b/,          'Notepad'],
    [qr/\bGwenview\b/,        'Photos'],
    [qr/\bKCalc\b/,           'Calculator'],
    [qr/\bKolourPaint\b/,     'Paint'],
    [qr/\bHaruna\b/,          'Media Player'],
    [qr/\bTrash\b/,           'Recycle Bin'],
    [qr/\btrash\b/,           'Recycle Bin'],
);

sub reword {
    my ($text) = @_;
    for my $key ("$domain|$text", $text) {
        return $exact{$key} if exists $exact{$key};
    }
    $text =~ s/$_->[0]/$_->[1]/g for @words;
    return $text;
}

# Joins a keyword's quoted pieces: ('msgid "a"', '"b"') -> 'ab' (escapes kept as written).
sub value {
    return join '', map { /"(.*)"\s*$/ ? $1 : '' } @_;
}

my $changed = 0;
local $/ = '';    # paragraph mode: one PO entry per read

while (my $entry = <STDIN>) {
    my (@comments, %field, $current);
    for my $line (split /\n/, $entry) {
        if ($line =~ /^#/) {
            push @comments, $line;
        } elsif ($line =~ /^(msgctxt|msgid_plural|msgid|msgstr(?:\[\d+\])?) /) {
            $current = $1;
            $field{$current} = [$line];
        } elsif ($line =~ /^"/ && defined $current) {
            push @{ $field{$current} }, $line;
        }
    }
    next unless exists $field{msgid};

    my $msgid = value(@{ $field{msgid} });
    my @out = @comments;
    push @out, map { @{ $field{$_} } } grep { exists $field{$_} } qw(msgctxt msgid msgid_plural);

    if ($msgid eq '') {
        # Header: keep as is (it carries the charset and plural rules).
        push @out, map { @{ $field{$_} } } grep { /^msgstr/ } sort keys %field;
    } elsif (exists $field{msgid_plural}) {
        my $plural = value(@{ $field{msgid_plural} });
        my ($one, $many) = (reword($msgid), reword($plural));
        $changed ||= $one ne $msgid || $many ne $plural;
        for my $key (sort grep { /^msgstr\[/ } keys %field) {
            push @out, qq{$key "} . ($key eq 'msgstr[0]' ? $one : $many) . '"';
        }
    } else {
        my $text = reword($msgid);
        $changed ||= $text ne $msgid;
        push @out, qq{msgstr "$text"};
    }
    print join("\n", @out), "\n\n";
}

exit($changed ? 0 : 1);
