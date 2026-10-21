#!/usr/bin/env bash
# =============================================================================
# prompts.sh — Interactieve invoer
# =============================================================================

# Ja/nee bevestiging
# Geeft 0 terug bij ja, 1 bij nee
prompt_confirm() {
    local question="${1:-Doorgaan?}"

    if "${SKIP_CONFIRM:-false}"; then
        log_info "(automatisch bevestigd) $question"
        return 0
    fi

    ui_release_terminal
    printf "\n  ${_CYAN}${_BOLD}?${_RESET}  %s ${_DIM}[J/n]${_RESET} " "$question" >&3
    local answer
    read -r answer
    answer="${answer,,}"  # lowercase

    if [[ -z "$answer" || "$answer" == "j" || "$answer" == "ja" || "$answer" == "y" || "$answer" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# Kies uit een lijst van opties
# Gebruik: prompt_choice "Label" "optie1" "optie2" ...
# Schrijft de keuze naar PROMPT_RESULT
prompt_choice() {
    local label="$1"
    shift
    local -a options=("$@")

    if "${SKIP_CONFIRM:-false}"; then
        PROMPT_RESULT="${options[0]}"
        log_info "(automatisch gekozen) $label: $PROMPT_RESULT"
        return 0
    fi

    ui_release_terminal
    printf "\n  ${_CYAN}${_BOLD}?${_RESET}  %s\n" "$label" >&3
    local i=1
    for opt in "${options[@]}"; do
        printf "     %d) %s\n" "$i" "$opt" >&3
        (( i++ ))
    done
    printf "  Keuze [1-%d]: " "${#options[@]}" >&3
    local answer
    read -r answer

    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#options[@]} )); then
        PROMPT_RESULT="${options[$((answer-1))]}"
        export PROMPT_RESULT
    else
        log_warn "Ongeldige keuze — eerste optie gebruikt."
        PROMPT_RESULT="${options[0]}"
        export PROMPT_RESULT
    fi
}

# Vrije tekstinvoer
# Gebruik: prompt_input "Vraag" "standaardwaarde"
# Schrijft de invoer naar PROMPT_RESULT
prompt_input() {
    local question="$1"
    local default="${2:-}"

    if "${SKIP_CONFIRM:-false}"; then
        PROMPT_RESULT="$default"
        log_info "(automatisch ingevuld) $question: $PROMPT_RESULT"
        export PROMPT_RESULT
        return 0
    fi

    ui_release_terminal
    if [[ -n "$default" ]]; then
        printf "\n  ${_CYAN}${_BOLD}?${_RESET}  %s ${_DIM}[%s]${_RESET}: " "$question" "$default" >&3
    else
        printf "\n  ${_CYAN}${_BOLD}?${_RESET}  %s: " "$question" >&3
    fi

    local answer
    read -r answer
    PROMPT_RESULT="${answer:-$default}"
    export PROMPT_RESULT
}
