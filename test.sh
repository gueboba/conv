#!/bin/sh
# Regression tests for conv. Builds real fixtures and converts them.
# Tests needing a tool you do not have are skipped, not failed.
set -u

CONV="$(cd "$(dirname "$0")" && pwd)/conv"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work" || exit 1

pass=0
fail=0
skip=0

ok()   { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
skipped() { skip=$((skip + 1)); printf '  skip  %s\n' "$1"; }

# makes OUTPUT ARGS... - the conversion must succeed and leave a real file
makes() {
    out="$1"
    shift
    rm -f "$out"
    if err="$("$CONV" "$@" 2>&1 >/dev/null)" && [ -s "$out" ]; then
        ok "$*"
    else
        bad "$* ${err:+- $err}"
    fi
}

# refuses ARGS... - the conversion must fail and exit non-zero
refuses() {
    if "$CONV" "$@" >/dev/null 2>&1; then
        bad "$* should have been refused"
    else
        ok "refuses: $*"
    fi
}

has() { command -v "$1" >/dev/null 2>&1; }

printf '\ndata formats\n'
printf 'name,age,city\nada,36,london\ngrace,45,"new york"\n' > people.csv
makes people.json  people.csv json
makes people.jsonl people.json jsonl
makes people.tsv   people.json tsv
makes people.plist people.json plist
makes round.csv    people.jsonl csv -o round.csv
if [ "$(tail -n 1 round.csv)" = "grace,45,new york" ]; then
    ok "csv -> json -> jsonl -> csv keeps the data"
else
    bad "csv round trip changed the data"
fi
if python3 -c 'import yaml' 2>/dev/null; then
    makes people.yaml people.json yaml
    makes fromyaml.csv people.yaml csv -o fromyaml.csv
else
    skipped "yaml (PyYAML not installed)"
fi
refuses people.csv mp3
printf '{"a": 1}\n' > object.json
refuses object.json csv
printf '{"a": 1,,}\n' > broken.json
refuses broken.json jsonl

printf '\narchives\n'
mkdir -p folder/sub
echo one > folder/a.txt
echo two > folder/sub/b.txt
makes folder.zip     folder zip
makes folder.tar.gz  folder.zip tar.gz
makes folder.tar.bz2 folder.tar.gz tar.bz2
makes folder.tar.xz  folder.tar.bz2 tar.xz
if tar -tJf folder.tar.xz | grep -q 'folder/sub/b.txt'; then
    ok "zip -> tar.gz -> tar.bz2 -> tar.xz keeps the tree"
else
    bad "archive round trip lost files"
fi
echo hello > note.txt
makes note.txt.gz  note.txt gz
makes note.txt.bz2 note.txt.gz bz2
makes note.zip     note.txt zip
refuses folder.zip txt
printf 'not an archive\n' > fake.zip
refuses fake.zip tar
python3 - <<'PY'
import io, tarfile
payload = b'pwned'
with tarfile.open('evil.tar', 'w') as tar:
    info = tarfile.TarInfo('../../escaped.txt')
    info.size = len(payload)
    tar.addfile(info, io.BytesIO(payload))
PY
refuses evil.tar zip
[ -e ../escaped.txt ] && bad "hostile tar escaped the working directory"

printf '\nimages\n'
if has ffmpeg; then
    ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc=size=200x150 \
        -frames:v 1 pic.png -y
    makes pic.jpg  pic.png jpg
    makes pic.webp pic.png webp
    makes pic.gif  pic.png gif
    makes pic.tiff pic.png tiff
    makes pic.bmp  pic.png bmp
    makes pic.pdf  pic.png pdf
    makes small.jpg pic.png jpg -q 20 -o small.jpg
    makes large.jpg pic.png jpg -q 95 -o large.jpg
    if [ "$(wc -c < small.jpg)" -lt "$(wc -c < large.jpg)" ]; then
        ok "-q changes the output size"
    else
        bad "-q had no effect"
    fi
    if [ "$(uname)" = Darwin ]; then
        makes pic.heic pic.png heic
        makes frompdf.png pic.pdf png -o frompdf.png
    fi
    refuses pic.png png
    refuses pic.png docx
    refuses missing.png jpg
else
    skipped "images (ffmpeg not installed)"
fi

printf '\naudio and video\n'
if has ffmpeg; then
    ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc=size=160x120:rate=10 \
        -f lavfi -i sine=frequency=440 -t 1 -shortest clip.mp4 -y
    ffmpeg -hide_banner -loglevel error -f lavfi -i sine=frequency=440:duration=1 \
        tone.wav -y
    makes tone.mp3  tone.wav mp3
    makes tone.flac tone.wav flac
    makes tone.m4a  tone.wav m4a
    makes tone.opus tone.wav opus
    makes rate.mp3  tone.wav mp3 -b 64k -o rate.mp3
    makes clip.mov  clip.mp4 mov
    makes clip.webm clip.mp4 webm
    makes clip.mp3  clip.mp4 mp3
    makes clip.gif  clip.mp4 gif
    makes frame.png clip.mp4 png -o frame.png
    refuses tone.wav mp4
else
    skipped "audio and video (ffmpeg not installed)"
fi

printf '\ndocuments\n'
if [ "$(uname)" = Darwin ] || has pandoc; then
    printf 'Hello there.\n\nSecond paragraph.\n' > doc.txt
    makes doc.rtf  doc.txt rtf
    makes doc.html doc.txt html
    makes doc.docx doc.txt docx
    makes doc.pdf  doc.txt pdf
    makes doc.odt  doc.docx odt
    makes back.txt doc.docx txt -o back.txt
    if diff -q doc.txt back.txt >/dev/null; then
        ok "txt -> docx -> txt keeps the text"
    else
        bad "document round trip changed the text"
    fi
    makes fromdocx.pdf doc.docx pdf -o fromdocx.pdf
    case "$(head -c 4 fromdocx.pdf)" in
        %PDF) ok "the pdf is really a pdf" ;;
        *)    bad "pdf output is not a pdf" ;;
    esac
else
    skipped "documents (no textutil and no pandoc)"
fi

printf '\nbehaviour\n'
cp people.csv guard.csv
"$CONV" guard.csv json -o guard.json >/dev/null 2>&1
refuses guard.csv json -o guard.json
makes guard.json guard.csv json -o guard.json -f
if "$CONV" guard.csv json -n 2>&1 | grep -q -- '->'; then
    ok "dry run reports a plan"
else
    bad "dry run printed nothing"
fi
if [ ! -e nothing.json ] && "$CONV" people.csv json -n -o nothing.json >/dev/null 2>&1 \
        && [ ! -e nothing.json ]; then
    ok "dry run writes nothing"
else
    bad "dry run touched the disk"
fi
cp people.csv same.csv
refuses people.csv same.csv json -d .
refuses people.csv json -q 500
if [ -z "$(ls -A .conv-* 2>/dev/null)" ]; then
    ok "no temporary files left behind"
else
    bad "temporary files left behind"
fi

printf '\n%s passed, %s failed, %s skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
