# conv

A universal file converter for the terminal. One command, one file, no dependencies.

```
conv photo.heic jpg
conv *.wav mp3
conv report.docx pdf
conv clip.mov gif
conv data.csv json
conv site.zip tar.gz
conv site.zip -x
```

The last argument is the format you want. That is the whole interface, and
`-x` unpacks instead of converting.

## Why

Converting a file usually means either uploading it to a website you would
rather not trust, or looking up ffmpeg's incantation for this particular pair
of formats. `conv` is the second option with the looking-up removed.

It is a single Python file with no dependencies, no configuration and no
telemetry. It converts data and archive formats itself, and for everything else
it hands the work to a tool you already have — ffmpeg, or on macOS the built-in
`sips`, `textutil` and `cupsfilter`.

## It runs entirely offline

Your files never leave the machine. `conv` imports no networking module, knows
no hostnames and opens no sockets; every backend it calls is a local binary.

You do not have to take that on faith. The test suite passes with the network
denied at the operating system level:

```sh
sandbox-exec -p '(version 1)(allow default)(deny network*)' ./test.sh
```

The only steps that need a connection are cloning this repository and, if you
want them, installing the optional backends. Converting never does.

## Install

```sh
git clone https://github.com/gueboba/conv.git
cd conv
./install.sh
```

That links `conv` into `~/.local/bin`. Pass a different directory to put it
somewhere else (`./install.sh /usr/local/bin`). Or skip the script entirely —
the file is self-contained, so copying `conv` anywhere on your `PATH` works.

Check what your machine can convert:

```sh
conv --list
```

## What it converts

| Kind | Formats | Needs |
| --- | --- | --- |
| Images | jpg, png, gif, bmp, tiff, webp, heic, avif, ico, icns, psd, jp2, tga, exr, dds, pdf | `sips` (macOS, built in) or ffmpeg |
| Images, read only | svg, and camera raw: cr2, cr3, nef, arw, dng, raf, orf, rw2, pef, srw | as above |
| Audio | mp3, wav, flac, aac, m4a, ogg, opus, aiff, wma, amr, ac3, caf | ffmpeg |
| Video | mp4, mov, mkv, avi, webm, m4v, wmv, flv, mpg, ts, ogv, 3gp | ffmpeg |
| Documents | txt, rtf, html, doc, docx, odt, wordml, webarchive, pdf | `textutil` and `cupsfilter` (macOS, built in) |
| Documents | md, epub, tex, rst | pandoc |
| Data | csv, tsv, json, jsonl, plist | nothing |
| Data | yaml | PyYAML |
| Archives | zip, tar, tar.gz, tar.bz2, tar.xz, gz, bz2, xz | nothing |

Some conversions cross categories and work anyway: a video to an audio file
(`conv clip.mov mp3`), a video to a gif, a video's first frame to a png, an
image to a pdf and back, a folder to an archive.

## Compressing and unpacking

Give any file an archive format to compress it, and pass `-x` to unpack one:

```sh
conv notes.txt gz          # notes.txt -> notes.txt.gz
conv folder zip            # a whole folder
conv site.zip tar.gz       # repack, without unpacking by hand
conv site.zip -x           # unpack into ./site/
conv notes.txt.gz -x       # the single file back, the way gzip -d does it
```

`-x` reads the format from the archive itself, so it takes no target format.
A `.zip` or `.tar` becomes a folder named after it; `.gz`, `.bz2` and `.xz`
hold exactly one file, so they give that file straight back. `-d` and `-o`
redirect the result, and as everywhere else nothing is overwritten without
`-f`.

## Options

```
-o PATH       write to this exact path (single input only)
-d DIR        write results into DIR instead of alongside the input
-x            unpack archives instead of converting them
-f            overwrite existing files
-q N          image quality, 1 to 100
-b RATE       audio or video bitrate, e.g. 192k
-n            dry run: show what would happen, change nothing
-v            print the commands being run
--list        show which converters are installed
```

Nothing is overwritten unless you pass `-f`. If two inputs in one command would
produce the same output file, `conv` stops before writing anything.

## How it works

Each format belongs to a category, and each pair of categories has a chain of
backends to try in order. Images prefer `sips` on macOS, then ImageMagick, then
ffmpeg, then Quick Look. Documents prefer pandoc, then `textutil`, then a trip
through CUPS for PDF output. If the first backend fails, the next one gets a
turn; you only see an error if they all give up.

A `.pdf` is treated as an image or as a document depending on what sits on the
other side of the conversion.

Output is written to a temporary file next to the destination and moved into
place only after the backend succeeds, so a failed conversion never leaves a
half-written file behind. Archives are unpacked with path traversal checks, so
a hostile `.zip` or `.tar` cannot write outside the folder you unpacked it
into — entries that climb out, or carry an absolute path, are refused and
nothing is written.

## Requirements

Python 3.8 or newer, standard library only — no pip install, ever. Everything
else is optional, and `conv --list` will tell you what you are missing and how
to get it.

## On iPhone and iPad

There is a companion app: [conv-ios](https://github.com/gueboba/conv-ios).
Same idea, no shared code — iOS cannot shell out to ffmpeg, so it is built on
Apple's own frameworks instead. It converts the same six categories, runs
entirely offline, and saves results to Photos, to Files, or to a share sheet.

## Tests

```sh
./test.sh
```

Builds real fixtures, runs conversions across every category, and checks that
the failure cases fail. Tests for tools you do not have installed are skipped.

## License

MIT
