#!/bin/sh
# Door smartd aangeroepen bij een schijfprobleem (smartd.conf: -M exec).
# Schrijft één regel die kingstra-health als melding in de sessie toont.
mkdir -p /var/lib/kingstra
printf '%s %s: %s\n' "$(date '+%Y-%m-%d %H:%M')" "${SMARTD_DEVICESTRING:-schijf}" \
    "${SMARTD_FAILTYPE:-probleem}" >> /var/lib/kingstra/smart-warnings
chmod 0644 /var/lib/kingstra/smart-warnings
