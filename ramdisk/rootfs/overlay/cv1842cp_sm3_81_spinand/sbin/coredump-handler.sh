#!/bin/sh
${CVI_SHOPTS}

CORE_DIR=${CORE_DIR:-/mnt/data/coredump}
SEQ_FILE="$CORE_DIR/.seq"
LOCK_DIR="$CORE_DIR/.lock"
TMP_CORE="$CORE_DIR/.core.$$"
TMP_META="$CORE_DIR/.meta.$$"
SEQ_TMP="$CORE_DIR/.seq.tmp.$$"

PROG_NAME=${1:-unknown}
PID_VALUE=${2:-unknown}
TIME_VALUE=${3:-unknown}
SIG_VALUE=${4:-unknown}

cleanup()
{
	rm -f "$TMP_CORE" "$TMP_META" "$SEQ_TMP"
	rmdir "$LOCK_DIR" 2>/dev/null
}

discard_stdin()
{
	cat >/dev/null
	exit 0
}

read_seq()
{
	seq_value=0

	if [ -r "$SEQ_FILE" ]; then
		seq_value=$(cat "$SEQ_FILE" 2>/dev/null)
	fi

	case "$seq_value" in
	''|*[!0-9]*)
		seq_value=0
		;;
	esac

	echo "$seq_value"
}

trap cleanup EXIT INT TERM

[ -d "$CORE_DIR" ] || mkdir -p "$CORE_DIR" || discard_stdin
[ -w "$CORE_DIR" ] || discard_stdin

cat > "$TMP_CORE" || exit 0

lock_retry=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
	lock_retry=$((lock_retry + 1))
	[ "$lock_retry" -ge 10 ] && exit 0
	sleep 1
done

seq_value=$(read_seq)
slot_index=$((seq_value % 2))
next_seq=$((seq_value + 1))

cat > "$TMP_META" <<EOF
slot=$slot_index
seq=$seq_value
prog=$PROG_NAME
pid=$PID_VALUE
time=$TIME_VALUE
signal=$SIG_VALUE
EOF

echo "$next_seq" > "$SEQ_TMP" && mv -f "$SEQ_TMP" "$SEQ_FILE"
mv -f "$TMP_CORE" "$CORE_DIR/core.$slot_index"
mv -f "$TMP_META" "$CORE_DIR/core.$slot_index.meta"
