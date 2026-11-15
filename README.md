# AudioBookBinder

**AudioBookBinder** is a macOS application and command-line utility for converting audio files (such as MP3s) into iPod/iPhone/Apple Books compatible audiobook files (`.m4b`) complete with chapter marks, cover artwork, and metadata.

---

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (including Command Line Tools)
- Git

---

## Checking Out the Code

Clone the repository recursively to fetch all submodules:

```bash
git clone --recurse-submodules https://github.com/gonzoua/AudioBookBinder.git
cd AudioBookBinder
```

If you have already cloned the repository without `--recurse-submodules`, initialize and update the submodules by running:

```bash
git submodule update --init --recursive
```

Swift package dependencies (such as `swift-argument-parser`) are automatically resolved by Xcode and `xcodebuild`.

---

## Building from Command Line

You can build AudioBookBinder from the command line using `xcodebuild`.

### Build the macOS Application (`AudioBookBinder.app`)


```bash
xcodebuild -scheme AudioBookBinder -configuration Release \
    -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

The compiled application bundle will be created at:
```text
build/Build/Products/Release/AudioBookBinder.app
```

### Build the Command Line Utility (`abbinder`)

To build the standalone command-line executable:


```bash
xcodebuild -scheme abbinder -configuration Release \
    -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

The compiled binary will be located at:
```text
build/Build/Products/Release/abbinder
```

---

## Command Line Utility: `abbinder`

### Usage

```bash
abbinder [-hsv] [-b bitrate] [-c 1|2] [-r samplerate] \
         [-a author] [-t title] [-g genre] \
         [-C cover.(jpg|png)] [-l hours] [-i filelist] -o outfile \
         [@chapter_1@ infile1 @chapter_2@ infile2 ...]
```

### Options

| Option | Argument | Description |
|---|---|---|
| `-a` | `author` | Set audiobook author (must be UTF-8). |
| `-b` | `bitrate` | Set bitrate in kbps. |
| `-c` | `1 \| 2` | Number of channels in audiobook (1 for mono, 2 for stereo). Default: `2`. |
| `-C` | `image` | Cover artwork file (JPEG and PNG formats supported). |
| `-e` | | Alias for `-E ""` (each file becomes a chapter with empty template). |
| `-E` | `template` | Create a chapter for each input file with name defined by template. |
| `-g` | `genre` | Set audiobook genre. |
| `-h` | | Show help/usage message. |
| `-i` | `file` | Read list of input files from a file, or `-` for standard input (`stdin`). |
| `-l` | `hours` | Split audiobook into volumes of maximum specified hours in length. |
| `-o` | `outfile` | Audiobook output file (`.m4b`). |
| `-q` | | Quiet mode (suppresses progress output). |
| `-r` | `rate` | Sample rate in Hz. Default: `44100`. |
| `-s` | | Skip files with errors and continue conversion. |
| `-t` | `title` | Set audiobook title (must be UTF-8). |
| `-v` | | Verbose mode; prints details about files being converted. |

#### Notes on Options

- **Author & Title (`-a`, `-t`):** Values must be UTF-8 encoded strings.
- **Cover Image (`-C`):** Supported image formats are JPEG and PNG.
- **Sample Rate (`-r`):** Supported sample rates are:  
  `8000`, `11025`, `12000`, `16000`, `22050`, `24000`, `32000`, `44100`, `48000`.

### Chapter Naming

Chapters can be defined either with explicit markers in the file list or by treating each source file as an individual chapter.

#### 1. Explicit Chapter Markers

Provide chapter names enclosed in `@` characters before the corresponding file names:

```bash
abbinder -o book.m4b '@Chapter 1@' track01.mp3 '@Chapter 2@' track02.mp3
```

#### 2. Automatic Chapter Names from File Metadata (`-E`)

Each file becomes a chapter named according to a template string. The template may include the following placeholders:

- `%N` – Chapter number (starts from 1)
- `%a` – Value of `artist` tag from source audio file
- `%t` – Value of `title` tag from source audio file

Example:
```bash
abbinder -E 'Chapter %N' -o book.m4b track01.mp3 track02.mp3
```

### Examples

- **Convert a single file to m4b:**
  ```bash
  abbinder -o book.m4b myfile.mp3
  ```

- **Convert several files to mono m4b with sample rate 8000 Hz:**
  ```bash
  abbinder -r 8000 -c 1 -o book.m4b myfile1.mp3 myfile2.mp3
  ```

- **Convert all MP3 files in a directory with author, title, and cover image:**
  ```bash
  find ./audio_dir -name '*.mp3' > list.txt
  abbinder -i list.txt -a "Author Name" -t "Book Title" -C cover.jpg -o out.m4b
  ```

- **Convert a three-chapter book with explicit chapter names:**
  ```bash
  abbinder -o book.m4b \
      '@The very beginning@' 01.mp3 \
      '@In the middle of something@' 02.mp3 \
      '@Ashes to ashes and dust to dust@' 03.mp3
  ```

- **Convert multiple short stories and make each of them a chapter using audio title tags:**
  ```bash
  abbinder -E '%t' -o stories.m4b story01.mp3 story02.mp3 story03.mp3
  ```
