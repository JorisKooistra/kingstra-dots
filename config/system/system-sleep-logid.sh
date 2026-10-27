#!/usr/bin/env bash
# =============================================================================
# kingstra-logid — systemd system-sleep hook
# =============================================================================
# Geïnstalleerd door kingstra-dots (fase 11) naar
# /usr/lib/systemd/system-sleep/kingstra-logid. Na resume verbindt de M720
# opnieuw; logid wordt dan herstart zodat de duimknop weer werkt.
# =============================================================================

case "${1:-}" in
    post)
        systemctl start --no-block kingstra-logid-refresh.service 2>/dev/null || true
        ;;
esac

exit 0
