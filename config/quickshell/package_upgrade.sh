#!/usr/bin/env bash
set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
COUNT_SCRIPT="${HOME}/.config/quickshell/package_updates.sh"
overall_exit=0

section() {
    printf '\n%s\n' "──────────────────────────────────────────────"
    printf '%s\n' "$1"
    printf '%s\n\n' "──────────────────────────────────────────────"
}

resolve_dotfiles_repo() {
    local marker="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/install-complete"
    local repo=""
    local script_path=""

    if [[ -f "$marker" ]]; then
        repo="$(sed -n 's/^Repo:[[:space:]]*//p' "$marker" | head -n 1)"
    fi
    if [[ -z "$repo" ]]; then
        script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
        if [[ -n "$script_path" ]]; then
            repo="$(cd "$(dirname "$script_path")/../.." 2>/dev/null && pwd -P || true)"
        fi
    fi

    [[ -n "$repo" && -d "$repo/.git" ]] || return 1
    printf '%s\n' "$repo"
}

update_dotfiles() {
    local repo=""
    local branch=""
    local upstream=""
    local behind=0
    local ahead=0

    repo="$(resolve_dotfiles_repo 2>/dev/null || true)"
    if [[ -z "$repo" ]]; then
        echo "Geen geïnstalleerde kingstra-dots git-repo gevonden; overgeslagen."
        return 0
    fi

    branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -z "$branch" ]]; then
        echo "Dotfiles-repo staat niet op een branch; overgeslagen."
        return 0
    fi

    if ! git -C "$repo" fetch --quiet origin "$branch"; then
        echo "Dotfiles ophalen mislukt."
        return 1
    fi

    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -z "$upstream" ]] && git -C "$repo" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        upstream="origin/$branch"
    fi
    if [[ -z "$upstream" ]]; then
        echo "Geen upstream voor branch '$branch'; overgeslagen."
        return 0
    fi

    behind="$(git -C "$repo" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
    ahead="$(git -C "$repo" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
    if [[ "$behind" -eq 0 ]]; then
        echo "Dotfiles zijn al actueel."
        return 0
    fi

    if [[ -n "$(git -C "$repo" status --porcelain --untracked-files=normal)" ]]; then
        echo "Er staan lokale wijzigingen in $repo."
        echo "Dotfiles-update veilig overgeslagen; commit of stash ze eerst."
        return 0
    fi
    if [[ "$ahead" -gt 0 ]]; then
        echo "De lokale branch loopt ook $ahead commit(s) voor op upstream."
        echo "Automatisch samenvoegen is overgeslagen."
        return 0
    fi

    echo "$behind nieuwe dotfiles-commit(s) gevonden."
    git -C "$repo" merge --ff-only "$upstream"
}

echo "=============================================="
echo " Kingstra Update Runner"
echo " yay · Flatpak · kingstra-dots"
echo "=============================================="

section "Arch/AUR"
if command -v yay >/dev/null 2>&1; then
    yay -Syu || overall_exit=$?
elif command -v paru >/dev/null 2>&1; then
    paru -Syu || overall_exit=$?
else
    echo "Geen yay of paru gevonden; Arch/AUR-update overgeslagen."
fi

section "Flatpak"
if command -v flatpak >/dev/null 2>&1; then
    flatpak update || overall_exit=$?
else
    echo "Flatpak is niet geïnstalleerd; overgeslagen."
fi

section "Dotfiles"
if ! update_dotfiles; then
    overall_exit=1
fi

mkdir -p "$CACHE_DIR"
rm -f "$CACHE_DIR/package_updates_status" "$CACHE_DIR/package_updates_count"
"$COUNT_SCRIPT" --refresh >/dev/null 2>&1 || true

section "Klaar"
if [[ $overall_exit -eq 0 ]]; then
    echo "Alle beschikbare updatebronnen zijn verwerkt."
else
    echo "Minstens één updatebron eindigde met een fout (code $overall_exit)."
fi
echo
read -r -p "Druk Enter om te sluiten..." _
exit "$overall_exit"
