#!/usr/bin/env bash
# Walker en Elephant draaien niet meer als achtergronddienst; de
# Quickshell-launcher is de enige launcher. Stop achtergebleven processen.

migration_run() {
    pkill -f "walker --gapplication-service" >/dev/null 2>&1 || true
    pkill -x elephant >/dev/null 2>&1 || true
    return 0
}
