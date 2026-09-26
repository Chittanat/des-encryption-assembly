INCLUDE Irvine32.inc

KeygenProc PROTO
EncryptProc PROTO
DecryptProc PROTO
EXTERN C DumpProc:PROC
EXTERN C StatsProc:PROC

.data
    promptMsg BYTE "DES-SHELL> ", 0
    cmdBuffer BYTE 100 DUP(0)
    
    arg1Pointer DWORD 0     ; เก็บ Address ของพารามิเตอร์ตัวที่ 1 (เช่น ชื่อไฟล์ หรือ คีย์)
    arg2Pointer DWORD 0     ; เก็บ Address ของพารามิเตอร์ตัวที่ 2 (เช่น คีย์ สำหรับคำสั่ง ENCRYPT)

    cmdExit    BYTE "EXIT", 0
    cmdClear   BYTE "CLEAR", 0
    cmdKeygen  BYTE "KEYGEN", 0
    cmdEncrypt BYTE "ENCRYPT", 0
    cmdDecrypt BYTE "DECRYPT", 0
    cmdDump    BYTE "DUMP", 0
    cmdStats   BYTE "STATS", 0

    unknownMsg BYTE "Error: Unknown command.", 0dh, 0ah, 0

.code
main PROC
ShellLoop:
    mov edx, OFFSET promptMsg
    call WriteString

    mov edx, OFFSET cmdBuffer
    mov ecx, SIZEOF cmdBuffer
    call ReadString

    ; --- กระบวนการ String Parsing (หั่นคำสั่งได้สูงสุด 3 ส่วน) ---
    mov esi, OFFSET cmdBuffer
    mov arg1Pointer, 0
    mov arg2Pointer, 0
    mov ebx, 0              ; ตัวนับช่องว่าง

ParseLoop:
    mov al, [esi]
    cmp al, 0
    je CheckCommand
    cmp al, ' '
    je FoundSpace
    inc esi
    jmp ParseLoop

FoundSpace:
    mov BYTE PTR [esi], 0   ; ตัดคำด้วย Null
    inc esi
    cmp ebx, 0
    je SetArg1
    cmp ebx, 1
    je SetArg2
    jmp ParseLoop

SetArg1:
    mov arg1Pointer, esi
    inc ebx
    jmp ParseLoop

SetArg2:
    mov arg2Pointer, esi
    inc ebx
    jmp ParseLoop

CheckCommand:
    INVOKE Str_compare, ADDR cmdBuffer, ADDR cmdExit
    je DoExit
    INVOKE Str_compare, ADDR cmdBuffer, ADDR cmdClear
    je DoClear
    INVOKE Str_compare, ADDR cmdBuffer, ADDR cmdKeygen
    je DoKeygen
    INVOKE Str_compare, ADDR cmdBuffer, ADDR cmdEncrypt
    je DoEncrypt
    INVOKE Str_compare, ADDR cmdBuffer, ADDR cmdDecrypt    ; <--- เพิ่มบรรทัดนี้
    je DoDecrypt
    INVOKE Str_compare, ADDR cmdBuffer, ADDR cmdDump
    je DoDump
    INVOKE Str_compare, ADDR cmdBuffer, ADDR cmdStats
    je DoStats

    ; ถ้าพิมพ์ผิด
    mov edx, OFFSET unknownMsg
    call WriteString
    jmp ShellLoop

DoClear:
    call Clrscr
    jmp ShellLoop

DoKeygen:
    mov esi, arg1Pointer
    call KeygenProc
    jmp ShellLoop

DoEncrypt:
    mov esi, arg1Pointer    ; ส่งชื่อไฟล์ไป
    mov edi, arg2Pointer    ; ส่งคีย์ไป
    call EncryptProc
    jmp ShellLoop

DoDecrypt:
    mov esi, arg1Pointer    ; ส่งชื่อไฟล์ encrypted.bin ไป
    mov edi, arg2Pointer    ; ส่งคีย์ไป
    call DecryptProc        ; เรียกฟังก์ชันถอดรหัสที่เราเพิ่งเขียน
    jmp ShellLoop

DoDump:
    mov esi, arg1Pointer
    call DumpProc
    jmp ShellLoop

DoStats:
    mov esi, arg1Pointer
    call StatsProc
    jmp ShellLoop

DoExit:
    exit
main ENDP
END main