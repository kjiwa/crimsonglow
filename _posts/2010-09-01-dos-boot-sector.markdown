---
title: DOS Boot Sector
description: >-
  Writing an MS-DOS-compatible boot sector in C: parsing the FAT BIOS parameter
  block, finding IO.SYS, and loading it via BIOS INT 13h in real mode.
---
I've been interested in writing an OS for a long time now. An OS consists of many components with one of the most fundamental being its booting mechanism. Had I been writing a production OS, I would have made use of a package such as GNU GRUB or LILO. However, as a hobbyist I was interested to know exactly what my PC was doing during the boot process. I decided that a good way to start would be to study a simple operating system -- MS-DOS. An MS-DOS boot sector has a very simple job: load the first 3 sectors of IO.SYS into memory and execute it.

After your BIOS completes its POST, an IBM PC compatible computer will read the first 512 B block from disk into memory at location 0x07C00 and begin executing it. The last 2 B of the boot sector must have the value 0xAA55; this value is known as the boot signature. This leaves 510 B for code.

MS-DOS expects the disk to be formatted with the FAT file system and will populate the boot sector with an 8 B OEM name and a 51 B data structure known as the BIOS parameter block. The first 3 B are expected to contain a jump instruction. This finally leaves us with 448 B for code. Had I been writing a production DOS boot sector, I would have written the code in an assembly language under such extreme constraints. However, as a philocalist and masochist I felt compelled to write legible code and decided to use C.

<div class="dos-boot-sector-table" role="region" aria-label="MS-DOS boot sector byte grid">
  <table role="presentation">
    <tbody>
    {% assign x = 0 %}
    {% for r in (0..15) %}
      <tr>
      {% for c in (0..31) %}
        {% if r == 0 or r == 1 or x == 510 or x == 511 %}
        <td class="dos-boot-sector-table-reserved-byte">&nbsp;</td>
        {% else %}
        <td>&nbsp;</td>
        {% endif %}
        {% assign x = x | plus: 1 %}
      {% endfor %}
      </tr>
    {% endfor %}
    </tbody>
  </table>
</div>
<div class="caption">Free and reserved bytes in an MS-DOS boot sector (1 B per square)</div>

The BIOS parameter block contains important information about the layout of the filesystem. Here is a table describing its layout:

<div class="dos-boot-sector-parameters"></div>

Length | Name
-------|----------------------------------
     2 | Bytes per sector
     1 | Sectors per cluster
     2 | Number of reserved sectors
     1 | Number of file allocation tables
     2 | Number of root entries
     2 | Number of sectors (if < 65 536)
     1 | Media descriptor
     2 | Sectors per file allocation table
     2 | Sectors per track
     2 | Number of heads
     4 | Number of hidden sectors
     4 | Number of sectors (if ≥ 65 536)
     1 | Disk drive index
     1 | Reserved
     1 | Volume signature
     4 | Volume ID
    11 | Volume label
     8 | Volume type

The CPU will be in real mode when the boot sector is loaded. This means we can only use 16-bit opcodes and address up to 1 MiB of memory. The first 640 KiB are available to our program while the remaining 384 KiB are used for assorted system-specific purposes. These memory areas are known as conventional memory and the upper memory area, respectively.

Some parts of conventional memory are reserved by the system. The first 1 024 B are used for the interrupt vector table and the next 256 B are used for the BIOS data area. Also, recall that the boot sector is loaded in 512 B in [0x07C00, 0x07E00). We can safely use 29.75 KiB in [0x00500, 0x07C00) and 480.5 KiB in [0x07E00, 0x80000) for a total of 510.25 KiB. There are also 128 KiB in [0x80000, 0xA0000), but some systems consume part of this region for the extended BIOS data area.

<div class="dos-boot-sector-table">
  <table>
    <tbody>
    {% assign x = 0 %}
    {% for r in (0..19) %}
      <tr>
      {% for c in (0..31) %}
        {% if x == 0 or x == 639 %}
        <td class="dos-boot-sector-table-reserved-byte">&nbsp;</td>
        {% elsif x == 1 or x == 30 or r == 16 or r == 17 or r == 18 or r == 19 %}
        <td class="dos-boot-sector-table-partially-reserved-byte">&nbsp;</td>
        {% else %}
        <td>&nbsp;</td>
        {% endif %}
        {% assign x = x | plus: 1 %}
      {% endfor %}
      </tr>
    {% endfor %}
    </tbody>
  </table>
</div>
<div class="caption">Free, partial, and reserved bytes in conventional memory (1 KiB per square)</div>

In my boot sector implementation, I use 5 B in [0x07E00, 0x07E05) to store the number of sectors on the disk and the logical block address of the root directory and IO.SYS. I use 29.75 KiB in [0x00500, 0x07C00) for the root directory index. Each root directory entry is 32 B, meaning that IO.SYS must be one of the first 952 entries. (MS-DOS 4.0 expects IO.SYS to be the first record in the root directory.) Here is a table describing the layout of each root directory entry:

<div class="dos-boot-sector-parameters"></div>

Length | Name
-------|-------------------------------------
     8 | Filename
     3 | Extension
     1 | Attributes
     1 | Reserved
     1 | Creation time (microseconds portion)
     2 | Creation time
     2 | Creation date
     2 | Last access date
     2 | Reserved
     2 | Last modified time
     2 | Last modified date
     2 | Cluster offset
     4 | File size in bytes

Dates are 16-bit, little-endian values stored in the following format: YYYYYYYMMMMDDDDD. Timestamps are 16-bit, little-endian values stored in the following format: HHHHHMMMMMMSSSSS.

Once IO.SYS is found, I store its first 3 sectors at 0x00700. I expect these 3 sectors to be unfragmented. This leaves 512 B in [0x00500, 0x00700) free for IO.SYS to store a copy of the boot sector later on.

Compiling the code into a raw binary with 16-bit opcodes became my next challenge. I was pleased to find that this is possible with GCC and binutils with a little bit of magic. First, I had to add the .code16gcc assembler directive to my C code. I also had to create a custom linker script to create a raw binary with a boot signature. The script instructs ld to construct a binary with a code segment, read-only data segment, and a boot signature. It also sets the instruction pointer to the correct memory offset.

The source code is released under the MIT license and is also available on GitHub at [github.com/kjiwa/x86-boot-sector-c](https://github.com/kjiwa/x86-boot-sector-c).

<div class="caption">boot.c</div>

{% highlight c %}
/*
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

// MS-DOS boot sector: loads IO.SYS from the root directory and executes it.

#ifndef __GNUC__
#error "This code requires GCC with inline assembly support"
#endif

asm(".code16gcc");

// Boot sector layout: 3-byte JMP, 59-byte BPB, then code.
asm("jmp _start");
asm(".space 0x003b");

typedef char int8_t;
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned long uint32_t;

// FAT12/16 boot sector structure matching the on-disk layout.
typedef struct __attribute__((packed)) {
  int8_t _a[3];
  int8_t name[8];
  uint16_t bytes_per_sector;
  uint8_t sectors_per_cluster;
  uint16_t reserved_sectors;
  uint8_t fats;
  uint16_t root_entries;
  uint16_t total_sectors;
  uint8_t media_descriptor;
  uint16_t sectors_per_fat;
  uint16_t sectors_per_track;
  uint16_t heads;
  uint32_t hidden_sectors;
  uint32_t total_sectors2;
  uint8_t drive_index;
  uint8_t _b;
  uint8_t signature;
  uint32_t id;
  int8_t label[11];
  int8_t type[8];
  uint8_t _c[448];
  uint16_t sig;
} boot_t;

// Track current disk operation: LBA address and sectors per track (from BIOS).
typedef struct {
  uint8_t sectors;
  uint32_t lba;
} disk_t;

// FAT directory entry: 8.3 filename format plus metadata.
typedef struct __attribute__((packed)) {
  int8_t filename[8];
  int8_t extension[3];
  uint8_t attributes;
  uint8_t _a;
  uint8_t create_time_us;
  uint16_t create_time;
  uint16_t create_date;
  uint16_t last_access_date;
  uint8_t _b[2];
  uint16_t last_modified_time;
  uint16_t last_modified_date;
  uint16_t cluster;
  uint32_t size;
} entry_t;

#define BOOT_SECTOR_ADDR 0x7c00
#define DISK_INFO_ADDR 0x7e00
#define ROOT_DIR_ADDR 0x0500
#define IO_SYS_LOAD_ADDR 0x0700
#define FIRST_HDD 0x80
#define IO_SYS_SECTORS 3
#define FILENAME_EXT_LEN 11

// BIOS loads the boot sector here during POST.
boot_t const *boot_sector = (boot_t *)BOOT_SECTOR_ADDR;

// Store disk geometry info right after boot sector in free memory.
disk_t *disk_info = (disk_t *)DISK_INFO_ADDR;

// IO.SYS in 8.3 format: "IO      " + "SYS"
int8_t const *io_sys_name = "IO      SYS";

// Multi-purpose buffer: first for root directory, then for IO.SYS itself.
uint8_t *buffer;

// Number of sectors to read in the next disk operation.
uint8_t sector_count;

// Current directory entry being examined during search.
entry_t const *current_entry;

// Compare directory entry name against "IO      SYS" (8.3 filename format).
// Standard string comparison: checks until mismatch, null terminator, or end of
// string.
int8_t is_io_sys(void) {
  uint16_t i;
  for (i = 0; i < FILENAME_EXT_LEN - 1 && ((int8_t *)current_entry)[i] &&
              ((int8_t *)current_entry)[i] == io_sys_name[i];
       ++i)
    ;
  return ((int8_t *)current_entry)[i] - io_sys_name[i];
}

// Read sectors from disk using BIOS INT 13h, AH=02h.
// Converts LBA to CHS since older BIOS doesn't support LBA addressing.
void read_sectors(void) {
  uint32_t sectors_per_cylinder = boot_sector->heads * disk_info->sectors;
  uint16_t cylinder = disk_info->lba / sectors_per_cylinder;
  uint16_t head = (disk_info->lba % sectors_per_cylinder) / disk_info->sectors;

  // Pack cylinder (10 bits) and sector (6 bits) into CX register format.
  cylinder <<= 8;
  cylinder |=
      ((disk_info->lba % sectors_per_cylinder) % disk_info->sectors) + 1;

  // INT 13h, AH=02h: Read sectors into memory
  // AL=sector_count, ES:BX=buffer, CX=cylinder/sector, DH=head, DL=drive
  asm("int $0x13"
      :
      : "a"(0x0200 | sector_count), "b"(buffer), "c"(cylinder),
        "d"((head << 8) | FIRST_HDD));
}

uint16_t _start(void) {
  // Get disk geometry using INT 13h, AH=08h.
  // CL bits 0-5 contain sectors per track.
  asm("int $0x13"
      : "=c"(disk_info->sectors)
      : "a"(0x0800), "d"(FIRST_HDD)
      : "bx");
  disk_info->sectors &= 0b00111111;

  // Calculate root directory location: after reserved sectors and both FATs.
  buffer = (uint8_t *)ROOT_DIR_ADDR;
  disk_info->lba = boot_sector->reserved_sectors +
                   (boot_sector->fats * boot_sector->sectors_per_fat);
  sector_count = boot_sector->root_entries * sizeof(entry_t) /
                 boot_sector->bytes_per_sector;
  read_sectors();

  // Scan root directory entries for IO.SYS.
  for (current_entry = (entry_t *)buffer;; ++current_entry)
    if (is_io_sys() == 0) {
      // Found IO.SYS. Calculate its location in the data area.
      // FAT cluster numbering starts at 2, so offset = (cluster - 2) *
      // sectors_per_cluster.
      buffer = (uint8_t *)IO_SYS_LOAD_ADDR;
      disk_info->lba += sector_count + (current_entry->cluster - 2) *
                                           boot_sector->sectors_per_cluster;
      sector_count = IO_SYS_SECTORS;
      read_sectors();

      // Transfer control to IO.SYS at 0000:0700
      asm("jmpw %0, %1" : : "g"(0x0000), "g"(IO_SYS_LOAD_ADDR));
    }

  return 0;
}
{% endhighlight %}
