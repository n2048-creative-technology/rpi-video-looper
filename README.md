# rpi-video-looper

A pre-built Raspberry Pi SD-card image (`rpi.img`, ~7.5 GiB decompressed) for
looping video playback, distributed as 310 split parts with checksums so it
fits under GitHub's per-file size limit.

**Status: NEEDS WORK.** This repo currently ships an opaque binary disk
image and nothing else — there is no visible source for whatever software,
scripts, or systemd services actually run the video loop on the Pi. Nobody
can audit, rebuild, or meaningfully contribute to this project from what's
here; they can only flash the exact image as-is. See
[Known issues](#known-issues-flagged-for-cleanup) below.

## What's in the repo

```
parts/
  rpi.manifest.txt      FORMAT/ORIGINAL_SHA256/PART_PREFIX + one checksum
                         line per part
  rpi.part000.part …
  rpi.part309.part      310 x 25 MiB chunks of the original 8,052,331,008-byte
                         (~7.5 GiB) rpi.img
scripts/
  join_img.sh            reassembles + SHA-256-verifies the parts back into
                          rpi.img
```

## Reassembling the image

```bash
./scripts/join_img.sh parts/rpi.manifest.txt rpi-video-looper.img
```

The script verifies every part's SHA-256 against the manifest as it
concatenates them, then verifies the final image's SHA-256 and size against
`ORIGINAL_SHA256` / `ORIGINAL_SIZE` in the manifest. It exits non-zero on any
mismatch — do not flash an image that fails verification.

Once you have `rpi-video-looper.img`, flash it to an SD card the normal way,
e.g. with [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or
`dd`:

```bash
sudo dd if=rpi-video-looper.img of=/dev/sdX bs=4M status=progress conv=fsync
```

(replace `/dev/sdX` with your SD card device — double-check with `lsblk`
first, `dd` will happily overwrite the wrong disk).

## Known issues (flagged for cleanup)

- **The whole point of this repo is a binary blob, not source.** A proper
  video-looper project would ship the actual playback script/service
  (whatever loops video on boot — commonly a `systemd` unit calling
  `omxplayer`/`vlc`/`mpv` in a loop, plus the Pi config that sets it up) so
  someone could read it, adapt it, or rebuild the image from a base
  Raspberry Pi OS install. None of that is here — only the finished disk
  image. If the image was built by hand or by a script, that script belongs
  in this repo.
- **Git history bloat.** The current git history is ~1.79 GiB packed
  (`git count-objects -vH`), almost entirely the `parts/*.part` files
  (224 blobs, ~5.4 GB across history revisions — parts were re-added/changed
  across commits). This makes every clone of this repo download gigabytes
  it doesn't need. A binary artifact like this is a much better fit for a
  **GitHub Release asset** (or the Releases feature's file upload, which
  isn't subject to git's diffing/packing overhead) than a committed file
  split into hundreds of chunks. Rewriting history to remove this
  (`git filter-repo` + re-upload the image as a Release asset) is a
  separate, larger job — flagging it here rather than attempting it.

## License

MIT — see [LICENSE](LICENSE). Note this only covers `scripts/join_img.sh`;
the license status of whatever is actually installed on the disk image
itself (Raspberry Pi OS, any player software, any media) is not
documented and should be checked separately before distributing the image
further.
