#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <iterations> <feature-slug>"
  exit 1
fi

tickets=".scratch/$2/issues"
spec=".scratch/$2/spec.md"

# Override for another CLI, e.g.:
#   export RALPH_AGENT='claude -p'
RALPH_AGENT=${RALPH_AGENT:-'pi -p --no-session'}

for ((i = 1; i <= $1; i++)); do
  echo "Durchlauf $i feature=$2"

  result=$(
    # shellcheck disable=SC2086
    $RALPH_AGENT "
Tickets: $tickets
Spec: $spec

Wenn kein Ticket mit Status ready-for-agent existiert, dessen Blocker alle done sind:
  gib genau <promise>COMPLETE</promise> aus und sonst nichts.

Sonst:
  nimm genau EIN solches Ticket (kleinste Nummer)
  implementiere es mit /implement
  überspringe /code-review — Review kommt in einer eigenen Session
  setze Status in dieser Ticket-Datei auf done
  committe
  NUR EIN TICKET.
"
  )

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "Tickets complete after $i iterations."
    exit 0
  fi
done
