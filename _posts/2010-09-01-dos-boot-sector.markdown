---
layout: post
title: DOS Boot Sector
date: 2010-09-01
---
I've been interested in writing an OS for a long time now. An OS consists of many components with one of the most fundamental being its booting mechanism. Had I been writing a production OS, I would have made use of a package such as GNU GRUB or LILO. However, as a hobbyist I was interested to know exactly what my PC was doing during the boot process. I decided that a good way to start would be to study a simple operating system -- MS-DOS. An MS-DOS boot sector has a very simple job: load the first 3 sectors of IO.SYS into memory and execute it.

After your BIOS completes its POST, an IBM PC compatible computer will read the first 512 B block from disk into memory at location 0x07C00 and begin executing it. The last 2 B of the boot sector must have the value 0xAA55; this value is known as the boot signature. This leaves 510 B for code.

MS-DOS expects the disk to be formatted with the FAT file system and will populate the boot sector with an 8 B OEM name and a 51 B data structure known as the BIOS parameter block. The first 3 B are expected to contain a jump instruction. This finally leaves us with 448 B for code. Had I been writing a production DOS boot sector, I would have written the code in an assembly language under such extreme constraints. However, as a philocalist and masochist I felt compelled to write legible code and decided to use C.

<div class="dos-boot-sector-table">
  <table>
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
  <div class="caption">Free and reserved bytes in an MS-DOS boot sector (1 B per square)</div>
</div>

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

Some parts of conventional memory are reserved by the system. The first 1 024 B are used for the interrupt vector table and the next 256 B are used for the BIOS data area. Also, recall that the boot sector is loaded in 512 B in [0x07C00, 0x07E00). We can safely use 29.75 KiB B in [0x00500, 0x07C00) and 480.5 KiB in [0x07E00, 0x80000) for a total of 510.25 KiB. There are also 128 KiB in [0x80000, 0xA0000), but some systems consume part of this region for the extended BIOS data area.

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
  <div class="caption">Free, partial, and reserved bytes in conventional memory (1 KiB per square)</div>
</div>

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

/**
 * An MS-DOS boot sector that reads the hard disk drive's root directory,
 * searches for IO.SYS, loads the first 3 sectors into memory, and executes it.
 */

// Tell GCC to emit 16-bit opcodes.
asm (".code16gcc");

// The first 3 bytes are reserved for a JMP instruction that we use to jump to
// the _start() method. The next 59 bytes are reserved for the OEM name and the
// BIOS parameter block. We set drive_index to be 0x80 to indicate we are
// booting from a hard disk drive.
asm ("jmp _start");
asm (".space 0x0021");
asm (".byte 0x80");
asm (".space 0x001c");

/**
 * Standard type definitions for the x86 in real mode.
 */
typedef char           s8_t;
typedef unsigned char  u8_t;
typedef unsigned short u16_t;
typedef unsigned long  u32_t;

/**
 * The boot sector.
 * @param _a                  3 reserved bytes used for a JMP instruction.
 * @param name                The OEM name of the volume.
 * @param bytes_per_sector    The number of bytes per sector.
 * @param sectors_per_cluster The number of sectors per cluster.
 * @param reserved_sectors    The number of reserved sectors.
 * @param fats                The number of file allocation tables.
 * @param root_entries        The number of entries in the root directory.
 * @param total_sectors       The number of hard disk sectors. If zero, use the
 *                                value in total_sectors2.
 * @param media_descriptor    The media descriptor.
 * @param sectors_per_fat     The number of sectors per file allocation table.
 * @param sectors_per_track   The number of sectors per track.
 * @param heads               The number of hard disk heads.
 * @param hidden_sectors      The number of hidden sectors.
 * @param total_sectors2      The number of hard disk sectors.
 * @param drive_index         The drive index.
 * @param _b                  Reserved.
 * @param signature           The extended boot signature.
 * @param id                  The volume ID.
 * @param label               The partition volume label.
 * @param type                The file system type.
 * @param _c                  Code to be executed.
 * @param sig                 The boot signature. Always 0xaa55.
 */
typedef struct {
  s8_t  _a[3];
  s8_t  name[8];
  u16_t bytes_per_sector;
  u8_t  sectors_per_cluster;
  u16_t reserved_sectors;
  u8_t  fats;
  u16_t root_entries;
  u16_t total_sectors;
  u8_t  media_descriptor;
  u16_t sectors_per_fat;
  u16_t sectors_per_track;
  u16_t heads;
  u32_t hidden_sectors;
  u32_t total_sectors2;
  u8_t  drive_index;
  u8_t  _b;
  u8_t  signature;
  u32_t id;
  s8_t  label[11];
  s8_t  type[8];
  u8_t  _c[448];
  u16_t sig;
} __attribute__ ((packed)) boot_t;

/**
 * Hard disk drive information.
 * @param sectors The number of sectors on the disk.
 * @param lba     The LBA of the block to read from the hard disk drive.
 */
typedef struct {
  u8_t  sectors;
  u32_t lba;
} FILE;

/**
 * A root directory entry.
 * @param filename           The file name.
 * @param extension          The file extension.
 * @param attributes         File attributes.
 * @param _a                 Reserved.
 * @param create_time_us     The microsecond value of the creation time.
 * @param create_time        The creation time.
 * @param create_date        The creation date.
 * @param last_access_date   The date the file was last accessed.
 * @param _b                 Reserved.
 * @param last_modified_time The time the file was last modified.
 * @param last_modified_date The date the file was last modified.
 * @param cluster            The cluster containing the start of the file.
 * @param size               The file size in bytes.
 */
typedef struct {
  s8_t  filename[8];
  s8_t  extension[3];
  u8_t  attributes;
  u8_t  _a;
  u8_t  create_time_us;
  u16_t create_time;
  u16_t create_date;
  u16_t last_access_date;
  u8_t  _b[2];
  u16_t last_modified_time;
  u16_t last_modified_date;
  u16_t cluster;
  u32_t size;
} __attribute__ ((packed)) entry_t;

/**
 * A pointer to the boot sector. After the BIOS POST, the boot sector is loaded
 * into memory at 0x7c00.
 */
boot_t const* _bs = (boot_t*) 0x7c00;

/**
 * A pointer to the hard disk drive information. We use 0x7e00, the first block
 * of available memory next to the boot sector.
 */
FILE* _disk = (FILE*) 0x7e00;

/**
 * A constant containing the name of the binary used to initialize the system
 * and device drivers. This is typically IO.SYS or IBMBIO.COM.
 */
s8_t const* _io_bin = "IO      SYS";

/**
 * A pointer to a general-purpose buffer in memory. Used to store the root
 * directory entries and the first 3 sectors of IO.SYS.
 */
u8_t* _buffer;

/**
 * A variable used by the read() method to indicate how many sectors to read
 * from the hard disk into memory.
 */
u8_t _size;

/**
 * A pointer to the root directory entry currently being read.
 */
entry_t const* _entry;

/**
 * Checks if the current root directory entry has the name IO.SYS by performing
 * a string comparison.
 * @return 0 if the current root directory entry has the name IO.SYS, a
 *     negative value if the entry name is less than IO.SYS, or a positive
 *     value if the entry name is greater than IO.SYS.
 */
s8_t iosyscmp() {
  u16_t i;
  for (i = 0;
       i < 10 && ((s8_t*) _entry)[i] && ((s8_t*) _entry)[i] == _io_bin[i];
       ++i);
  return ((s8_t*) _entry)[i] - _io_bin[i];
}

/**
 * Reads sectors at the provided LBA from the hard disk into memory. Uses the
 * value stored in _size as the number of sectors to read.
 * @return 0
 */
u16_t read() {
  // convert the LBA into CHS values
  u32_t t = _bs->heads * _disk->sectors;
  u16_t c = _disk->lba / t;
  u16_t h = (_disk->lba % t) / _disk->sectors;
  c <<= 8;
  c |= ((_disk->lba % t) % _disk->sectors) + 1;

  // read sectors from the hard disk into memory at 0x0500
  asm ("int $0x13" : : "a"(0x0200 | _size), "b"(_buffer), "c"(c), "d"((h << 8) | 0x0080));
  return 0;
}

/**
 * Reads drive information, searches for IO.SYS, loads the first 3 sectors into
 * memory, and begins executing it.
 * @return 0
 */
u16_t _start() {
  // read hard disk drive information into memory at 0x7e00
  asm ("int $0x13" : "=c"(_disk->sectors) : "a"(0x0800), "d"(0x80) : "bx");
  _disk->sectors &= 0b00111111;

  // read the root directory into memory at 0x500
  _buffer = (u8_t*) 0x0500;
  _disk->lba = _bs->reserved_sectors + (_bs->fats * _bs->sectors_per_fat);
  _size = _bs->root_entries * sizeof(entry_t) / _bs->bytes_per_sector;
  read();

  // iterate over root directory entries and look for IO.SYS
  for (_entry = (entry_t*) _buffer; ; ++_entry)
    if (iosyscmp() == 0) {
      // load the first 3 sectors of IO.SYS into memory at 0x0700
      _buffer = (u8_t*) 0x0700;
      _disk->lba += _size + (_entry->cluster - 2) * _bs->sectors_per_cluster;
      _size = 3;
      read();

      // execute IO.SYS
      asm ("jmpw %0, %1" : : "g"(0x0000), "g"(0x0700));
    }

  return 0;
}
{% endhighlight %}
