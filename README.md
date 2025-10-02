# Barebones x86 kernel in zig

## Build
Prerequisites:
 - zig 0.15.1
```sh
zig build
```
## Run with qemu
Prerequisites:
 - qemu-system-i386
```sh
zig build qemu
```
## Debug with gdb
Prerequisites:
 - qemu-system-i386
 - gdb
```sh
zig build gdb

# To get serial console open another terminal and:
zig build tty
```

## Debug with lldb
Prerequisites:
 - qemu-system-i386
 - lldb
```sh
zig build lldb

# To get serial console open another terminal and:
zig build tty
```
