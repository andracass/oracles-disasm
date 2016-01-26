; Call Across Bank
.MACRO callab
	.IF NARGS == 1
		ld hl,\1
		ld e,:\1
		call interBankCall
	.ELSE
		ld hl,\2
		ld e,\1
		call interBankCall
	.ENDIF
.ENDM

; Jump Across Bank
.MACRO jpab
	.IF NARGS == 1
		ld hl,\1
		ld e,:\1
		jp interBankCall
	.ELSE
		ld hl,\2
		ld e,\1
		jp interBankCall
	.ENDIF
.ENDM

.MACRO setrombank
	ldh (<hRomBank),a
	ld ($2222),a
.ENDM

; Call from bank 0
.MACRO callfrombank0
	.IF NARGS == 1
		ld a,:\1
		ldh (<hRomBank),a
		ld ($2222),a
		call \1
	.ELSE
		ld a,\1
		ldh (<hRomBank),a
		ld ($2222),a
		call \2
	.ENDIF
.ENDM

; Jump from bank 0
.MACRO jpfrombank0
	.IF NARGS == 1
		ld a,:\1
		ldh (<hRomBank),a
		ld ($2222),a
		jp \1
	.ELSE
		ld a,\1
		ldh (<hRomBank),a
		ld ($2222),a
		jp \2
	.ENDIF
.ENDM

; RSTs
.MACRO rst_jumpTable
	rst $00
.ENDM
.MACRO rst_addAToHl
	rst $10
.ENDM
.MACRO rst_addDoubleIndex
	rst $18
.ENDM

; Pointers
.MACRO 3BytePointer
        .db :\1
        .dw \1
.ENDM
.MACRO Pointer3Byte
        .dw \1
        .db :\1
.ENDM

; dwbe = define word big endian
.MACRO dwbe
	.IF NARGS > 3
		.PRINTT "dwbe only supports up to 3 arguments.\n"
		.FAIL
	.ENDIF

	.db \1>>8
	.db \1&$ff

	.IF NARGS > 1
		.db \2>>8
		.db \2&$ff
	.ENDIF
	.IF NARGS > 2
		.db \3>>8
		.db \3&$ff
	.ENDIF
.ENDM

; Parameters:
; 1-2: Unknown
; 3 - Top of stack
; 4 - A function
.MACRO m_ThreadState
	.db \1 \2
	.dw \3
	.dw \4
	.db $00 $00
.ENDM

; ARG 1: actual address
; ARG 2: relative address
.MACRO m_RelativePointer
	.IF NARGS == 2
		.dw (((\1)&$3fff+(:\1)*$4000) - (\2&$3fff+(:\2)*$4000))&$ffff
	.ELSE
		.dw (((\1)&$3fff+(:\1)*$4000) - (\3&$3fff+(:\2)*$4000))&$ffff
	.ENDIF
.ENDM

; Same as above but always use absolute numbers instead of labels
.MACRO m_RelativePointerAbs
	.dw ((\1) - \2)&$ffff
.ENDM

; Macro which allows data to cross over banks, used for map layout data.
; Doesn't support more than 1 bank crossing at a time
; Must have DATA_ADDR and DATA_BANK defined before use.
; ARG 1: name
.macro m_RoomLayoutData
	.FOPEN "build/rooms/\1.cmp" m_DataFile
	.FSIZE m_DataFile SIZE
	.FCLOSE m_DataFile
	.REDEFINE SIZE SIZE-1

	.IF DATA_ADDR + SIZE >= $8000
		.REDEFINE DATA_READAMOUNT $8000-DATA_ADDR
		\1: .incbin "build/rooms/\1.cmp" SKIP 1 READ DATA_READAMOUNT
		.REDEFINE DATA_BANK DATA_BANK+1
		.BANK DATA_BANK SLOT 1
		.ORGA $4000
                .IF DATA_READAMOUNT < SIZE
                        .incbin "build/rooms/\1.cmp" SKIP DATA_READAMOUNT+1
                .ENDIF
		.REDEFINE DATA_ADDR $4000 + SIZE-DATA_READAMOUNT
	.ELSE
		\1: .incbin "build/rooms/\1.cmp" SKIP 1
		.REDEFINE DATA_ADDR DATA_ADDR + SIZE
	.ENDIF

	.UNDEFINE SIZE
.endm

; Pointer to room data defined with m_RoomLayoutData
; ARG 1: name
; ARG 2: relative offset
.macro m_RoomLayoutPointer
	.FOPEN "build/rooms/\1.cmp" m_DataFile
	.FREAD m_DataFile mode
	.FCLOSE m_DataFile

        .IF mode == 3
                ; Mode 3 is dictionary compression, for large rooms, handled fairly differently
                m_RoomLayoutDictPointer \1 \2
        .ELSE
                .dw ((:\1*$4000)+(\1&$3fff) - ((:\2*$4000)+(\2&$3fff))) | (mode<<14)
        .ENDIF

	.undefine mode
.endm

; Pointer to room data with dictionary compression
; This macro doesn't require a corresponding file to exist, just a label
; ARG 1: name
; ARG 2: relative offset
.macro m_RoomLayoutDictPointer
        .dw ((:\1*$4000)+(\1&$3fff) - ((:\2*$4000)+(\2&$3fff))) + $200
.ENDM

; Macro to define palette headers for the background
; ARG 1: index of first palette to load the data into
; ARG 2: number of palettes to load
; ARG 3: address of palette data
; ARG 4: $80 to continue reading palette headers, $00 to stop
.macro m_PaletteHeaderBg
	.db (\2-1) | (\1<<3) | \4
	.dw \3
.ENDM

; Macro to define palette headers for sprites
; ARG 1: index of first palette to load the data into
; ARG 2: number of palettes to load
; ARG 3: address of palette data
; ARG 4: $80 to continue reading palette headers
.macro m_PaletteHeaderSpr
	.db (\2-1) | (\1<<3) | \4 | $40
	.dw \3
.ENDM

; Args 1-3: colors
.macro m_RGB16
	.IF \1 > $1f 
		.PRINTT "m_RGB16: Color components must be between $00 and $1f\n"
		.FAIL
	.ENDIF
	.IF \2 > $1f 
		.PRINTT "m_RGB16: Color components must be between $00 and $1f\n"
		.FAIL
	.ENDIF
	.IF \3 > $1f 
		.PRINTT "m_RGB16: Color components must be between $00 and $1f\n"
		.FAIL
	.ENDIF
	.dw \1 | (\2<<5) | (\3<<10)
.endm

; Args:
; 1 - Label: name
; 2 - Byte: Compression mode ($00 or $80)
.macro m_TilesetDictionaryHeader
	.db :\1 | \2
	dwbe \1
.endm

; Args:
; 1 - Byte: dictionary index (for compression)
; 2 - Label: Compressed data to load
; 3 - Word: Destination (multiple of 0x10)
; 4 - Byte: Destination wram/vram bank
; 5 - Word: Data size in bytes
.macro m_TilesetHeader
	.db \1
	.db :\2
	dwbe \2
	dwbe \3 | :\3
	dwbe \4 | (\5<<8)
.endm

.macro m_TilesetData
	\1: .incbin "build/tilesets/\1.cmp"
.endm


; Args:
; 1 - Byte: Opcode
; 2 - Byte: Src map
; 3 - Byte: Index
; 4 - 4bit: Y or Group src
; 5 - 4bit: X or Entrance mode
.macro m_StandardWarp
	.db \1 \2 \3 (\4<<4)|\5
.endm

; Same as StandardWarp, except \2 represents YX.
; This only exists to help LynnaLab distinguish the 2.
.macro m_PointedWarp
	.db \1 \2 \3 (\4<<4)|\5
.endm

; Args:
; 1 - Byte: Opcode
; 2 - Byte: Src map
; 3 - Pointer
.macro m_PointerWarp
	.db \1 \2
	.dw \3
.endm

.macro m_WarpSourcesEnd
	.db $ff $00 $00 $00
.endm

; Args:
; 1 - Byte: map
; 2 - Byte: YX
; 3 - Byte: unknown
.macro m_WarpDest
	.db \1 \2 \3
.endm
