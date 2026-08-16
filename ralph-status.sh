#!/bin/bash

usage() {
	echo "Usage: $0 <feature-slug>" >&2
	exit 2
}

refuse() {
	echo "ralph-status: $1" >&2
	exit 2
}

if [ "$#" -ne 1 ] || [ "$1" = "--help" ]; then
	usage
fi

slug=$1

if [ -z "$slug" ] || [ "$slug" = "." ] || [ "$slug" = ".." ] || [[ "$slug" == */* ]]; then
	usage
fi

issues=".scratch/${slug}/issues"

if [ ! -d "$issues" ]; then
	echo "ralph-status: no issues directory at ${issues}" >&2
	exit 2
fi

first_token() {
	local rest=$1
	rest="${rest#"${rest%%[![:space:]]*}"}"
	printf '%s' "${rest%%[[:space:]]*}"
}

canonical_status() {
	local token
	token=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	case "$token" in
	needs-triage | needs-info | ready-for-agent | ready-for-human | wontfix | done | claimed | resolved)
		printf '%s' "$token"
		return 0
		;;
	esac
	return 1
}

# Sets field_name and field_rest when $1 is a Status or Blocked-by field line.
parse_field_line() {
	local line=$1
	local trimmed spec body key
	trimmed="${line#"${line%%[![:space:]]*}"}"
	if [[ "$trimmed" =~ ^\*\*([^:]+):\*\*(.*)$ ]]; then
		spec=${BASH_REMATCH[1]}
		body=${BASH_REMATCH[2]}
	elif [[ "$trimmed" =~ ^([^:]+):(.*)$ ]]; then
		spec=${BASH_REMATCH[1]}
		body=${BASH_REMATCH[2]}
	else
		return 1
	fi
	key=$(printf '%s' "$spec" | tr '[:upper:]' '[:lower:]')
	case "$key" in
	status)
		field_name=status
		;;
	"blocked by" | "blocked-by")
		field_name=blocked-by
		;;
	*)
		return 1
		;;
	esac
	field_rest=$body
	return 0
}

# Sets parsed_blockers. Returns 1 if the value is not a legal blocker list.
# none / keine (optionally followed by prose) or an empty value means no blockers.
# Otherwise comma-separated numbers. Numbers compare numerically (01 == 1).
parse_blockers() {
	local rest=$1
	local token trimmed first first_lc remaining
	parsed_blockers=()
	rest="${rest#"${rest%%[![:space:]]*}"}"
	rest="${rest%"${rest##*[![:space:]]}"}"
	if [ -z "$rest" ]; then
		return 0
	fi
	if [[ "$rest" != *,* ]]; then
		first=$(first_token "$rest")
		first_lc=$(printf '%s' "$first" | tr '[:upper:]' '[:lower:]')
		if [ "$first_lc" = "none" ] || [ "$first_lc" = "keine" ]; then
			return 0
		fi
		if [[ "$rest" =~ ^[0-9]+$ ]]; then
			parsed_blockers=("$((10#$rest))")
			return 0
		fi
		return 1
	fi
	remaining=$rest
	while [ -n "$remaining" ]; do
		token=${remaining%%,*}
		if [ "$token" = "$remaining" ]; then
			remaining=
		else
			remaining=${remaining#*,}
		fi
		trimmed="${token#"${token%%[![:space:]]*}"}"
		trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
		if [ -z "$trimmed" ]; then
			continue
		fi
		if [[ "$trimmed" =~ ^[0-9]+$ ]]; then
			parsed_blockers+=("$((10#$trimmed))")
		else
			return 1
		fi
	done
	return 0
}

blocker_set_key() {
	local out= n
	if [ "$#" -eq 0 ]; then
		printf ''
		return
	fi
	while IFS= read -r n; do
		if [ -z "$out" ]; then
			out=$n
		else
			out="$out $n"
		fi
	done <<EOF
$(printf '%s\n' "$@" | sort -n -u)
EOF
	printf '%s' "$out"
}

read_ticket() {
	local file=$1
	local line status_token canon this_key
	local status_seen=0
	local blockers_seen=0
	local first_blocker_key=
	ticket_status=
	blockers=()
	while IFS= read -r line || [ -n "$line" ]; do
		if ! parse_field_line "$line"; then
			continue
		fi
		if [ "$field_name" = "status" ]; then
			status_token=$(first_token "$field_rest")
			if ! canon=$(canonical_status "$status_token"); then
				refuse "unreadable status in ${file}"
			fi
			if [ "$status_seen" -eq 0 ]; then
				ticket_status=$canon
				status_seen=1
			elif [ "$canon" != "$ticket_status" ]; then
				refuse "conflicting status in ${file}"
			fi
		elif [ "$field_name" = "blocked-by" ]; then
			if ! parse_blockers "$field_rest"; then
				refuse "unreadable blockers in ${file}"
			fi
			this_key=$(blocker_set_key "${parsed_blockers[@]}")
			if [ "$blockers_seen" -eq 0 ]; then
				blockers=("${parsed_blockers[@]}")
				first_blocker_key=$this_key
				blockers_seen=1
			elif [ "$this_key" != "$first_blocker_key" ]; then
				refuse "conflicting blockers in ${file}"
			fi
		fi
	done <"$file"
	if [ "$status_seen" -eq 0 ]; then
		refuse "missing status in ${file}"
	fi
}

blocker_is_done() {
	local b=$1
	local d
	[ ${#done_nums[@]} -eq 0 ] && return 1
	for d in "${done_nums[@]}"; do
		[ "$d" = "$b" ] && return 0
	done
	return 1
}

sort_stems() {
	local -a rows=("$@")
	local row
	sorted_stems=()
	[ ${#rows[@]} -eq 0 ] && return 0
	while IFS= read -r row; do
		sorted_stems+=("${row#*	}")
	done <<EOF
$(printf '%s\n' "${rows[@]}" | sort -n -k1,1)
EOF
}

done_rows=()
done_nums=()
rfa_entries=()
seen_nums=()
wayfinder=0

shopt -s nullglob
for path in "$issues"/*; do
	[ -f "$path" ] || continue
	base=${path##*/}
	[[ "$base" =~ ^[0-9]+-.+\.md$ ]] || continue
	num=$((10#${base%%-*}))
	stem=${base%.md}
	if [ ${#seen_nums[@]} -gt 0 ]; then
		for seen in "${seen_nums[@]}"; do
			if [ "$seen" = "$num" ]; then
				refuse "duplicate ticket number ${num}"
			fi
		done
	fi
	seen_nums+=("$num")
	if [ ! -r "$path" ]; then
		refuse "cannot read ${path}"
	fi
	read_ticket "$path"
	if [ "$ticket_status" = "claimed" ] || [ "$ticket_status" = "resolved" ]; then
		wayfinder=1
	elif [ "$ticket_status" = "done" ]; then
		done_rows+=("$num	$stem")
		done_nums+=("$num")
	elif [ "$ticket_status" = "ready-for-agent" ]; then
		rfa_entries+=("$num	$stem	${blockers[*]}")
	fi
done

if [ "$wayfinder" -eq 1 ]; then
	refuse "feature is Wayfinder"
fi

frontier_rows=()
if [ ${#rfa_entries[@]} -gt 0 ]; then
	for entry in "${rfa_entries[@]}"; do
		num=${entry%%	*}
		rest=${entry#*	}
		stem=${rest%%	*}
		csv=${rest#*	}
		all_done=1
		for b in $csv; do
			if ! blocker_is_done "$b"; then
				all_done=0
				break
			fi
		done
		if [ "$all_done" -eq 1 ]; then
			frontier_rows+=("$num	$stem")
		fi
	done
fi

sort_stems "${frontier_rows[@]}"
frontier_stems=("${sorted_stems[@]}")
sort_stems "${done_rows[@]}"
done_stems=("${sorted_stems[@]}")

if [ ${#frontier_stems[@]} -gt 0 ]; then
	decision=GO
	exit_code=0
else
	decision=NO-GO
	exit_code=1
fi

printf '%s\n' "$decision" "" "Frontier"
if [ ${#frontier_stems[@]} -gt 0 ]; then
	printf '%s\n' "${frontier_stems[@]}"
fi
printf '%s\n' "" "Done"
if [ ${#done_stems[@]} -gt 0 ]; then
	printf '%s\n' "${done_stems[@]}"
fi
exit "$exit_code"
