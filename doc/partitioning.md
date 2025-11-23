# Partitioning

My Linux systems rely on [BTRFS](https://en.wikipedia.org/wiki/Btrfs), _"a file system based on the copy-on-write (COW) principle"_.
I want a robust yet hackable distribution. This storage format provides many useful features. It supports snapshots with rollback capabilities, includes a logical volume manager that can be used `online`, offers `send-receive` functionality for working with subvolumes, and provides built-in checking and repair tools.

| Partition   | Size | Type            | Mount Point | Notes                                              |
| ----------- | ---- | --------------- | ----------- | -------------------------------------------------- |
| Partition 1 | 1GB  | XBOOTLDR (vfat) | /boot       | —                                                  |
| Partition 2 | 1GB  | EFI (vfat)      | /efi        | —                                                  |
| Partition 3 | 100% | ROOT (btrfs)    | /           | with `@system-base` subvolume and `@unstable-base` |
