INCLUDE Irvine32.inc

; ประกาศฟังก์ชันให้ไฟล์อื่นเรียกใช้ได้
PUBLIC DumpProc
PUBLIC StatsProc
PUBLIC OpenFiles
PUBLIC OpenDecFiles
PUBLIC CloseFiles
PUBLIC ReadBlock       ; <--- เพิ่ม: ฟังก์ชันอ่านทีละ 8 ไบต์
PUBLIC WriteBlock      ; <--- เพิ่ม: ฟังก์ชันเขียนทีละ 8 ไบต์
PUBLIC buffer          ; <--- เพิ่ม: ให้ des_core.asm มองเห็นบัฟเฟอร์นี้ได้
PUBLIC bytesRead       ; <--- เพิ่ม: ให้ des_core.asm รู้ว่าอ่านมาได้กี่ไบต์

.data
    inHandle  DWORD ?       ; เก็บหมายเลขประจำตัว (Handle) ของไฟล์ต้นฉบับ
    outHandle DWORD ?       ; เก็บหมายเลขประจำตัว (Handle) ของไฟล์ปลายทาง
    
    outFileName BYTE "encrypted.bin", 0   ; ชื่อไฟล์ผลลัพธ์ที่เราจะสร้างขึ้นมาใหม่
    
    errOpenMsg BYTE "Error: Cannot open input file!", 0dh, 0ah, 0
    errCreateMsg BYTE "Error: Cannot create output file!", 0dh, 0ah, 0
    successMsg BYTE "File I/O Ready: dummy.txt -> encrypted.bin", 0dh, 0ah, 0

    ; --- เพิ่มตัวแปรสำหรับพักข้อมูล ---
    buffer BYTE 8 DUP(0)    ; ถาดพักข้อมูลขนาด 8 ไบต์ (64 บิต)
    bytesRead DWORD 0       ; เก็บตัวเลขว่าอ่านข้อมูลมาได้กี่ไบต์ในรอบนี้

    decFileName BYTE "decrypted.txt", 0   
 decSuccessMsg BYTE "File I/O Ready: encrypted.bin -> decrypted.txt", 0dh, 0ah, 0

 dumpHeaderMsg BYTE "Offset (h)  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F  Decoded Text", 0dh, 0ah
              BYTE "-------------------------------------------------------------------------", 0dh, 0ah, 0
dumpFileHandle DWORD ?
dumpBuffer BYTE 16 DUP(0) ; อ่านทีละ 16 ไบต์สำหรับการแสดงผล 1 บรรทัด
dumpBytesRead DWORD 0
currentOffset DWORD 0
spaceChar BYTE " ", 0
dotChar BYTE ".", 0
separatorMsg BYTE "  ", 0

statsHeaderMsg BYTE "Byte Frequency Histogram:", 0dh, 0ah
                BYTE "-------------------------", 0dh, 0ah, 0
 freqTable DWORD 256 DUP(0)      ; ตารางเก็บความถี่ 256 ช่อง (0x00 ถึง 0xFF)
 statsBuffer BYTE 256 DUP(0)     ; บัฟเฟอร์สำหรับอ่านไฟล์
 statsBytesRead DWORD 0
 statsItemMsg BYTE "Hex: ", 0
 statsCountMsg BYTE " | Count: ", 0

.code
; ---------------------------------------------------------
; OpenFiles: เปิดไฟล์อ่านและสร้างไฟล์เขียน
; รับค่า: EDX = ชี้ไปที่ชื่อไฟล์ต้นฉบับ
; ส่งคืน: EAX = 1 (สำเร็จ), EAX = 0 (พัง)
; ---------------------------------------------------------
OpenFiles PROC C
    ; 1. ขอ Windows เปิดไฟล์ต้นฉบับสำหรับอ่าน
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    jne OpenOutput
        
    ; ถ้าเปิดไม่สำเร็จ (เช่น พิมพ์ชื่อไฟล์ผิด หรือไม่มีไฟล์)
    mov edx, OFFSET errOpenMsg
    call WriteString
    mov eax, 0
    ret

OpenOutput:
    mov inHandle, eax       ; เก็บ Handle ของไฟล์ต้นฉบับไว้ใช้ตอนอ่าน
        
    ; 2. ขอ Windows สร้างไฟล์ปลายทางสำหรับเขียนผลลัพธ์
    mov edx, OFFSET outFileName
    call CreateOutputFile
    cmp eax, INVALID_HANDLE_VALUE
    jne InitSuccess
        
    ; ถ้าสร้างไม่สำเร็จ (เช่น ติด Permission)
    mov edx, OFFSET errCreateMsg
    call WriteString
    mov eax, 0
    ret

InitSuccess:
    mov outHandle, eax      ; เก็บ Handle ของไฟล์ปลายทางไว้ใช้ตอนเขียน
    mov edx, OFFSET successMsg
    call WriteString
    mov eax, 1
    ret
OpenFiles ENDP

OpenDecFiles PROC C
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    jne OpenDecOutput
    mov edx, OFFSET errOpenMsg
    call WriteString
    mov eax, 0
    ret

OpenDecOutput:
    mov inHandle, eax       
    mov edx, OFFSET decFileName
    call CreateOutputFile
    cmp eax, INVALID_HANDLE_VALUE
    jne DecInitSuccess
    mov edx, OFFSET errCreateMsg
    call WriteString
    mov eax, 0
    ret

DecInitSuccess:
    mov outHandle, eax      
    mov edx, OFFSET decSuccessMsg
    call WriteString
    mov eax, 1
    ret
OpenDecFiles ENDP

; ---------------------------------------------------------
; CloseFiles: ปิดไฟล์ทั้งสองและคืนทรัพยากรให้ OS
; ---------------------------------------------------------
CloseFiles PROC C
    mov eax, inHandle
    call CloseFile
    
    mov eax, outHandle
    call CloseFile
    ret
CloseFiles ENDP

; ---------------------------------------------------------
; ReadBlock: ดึงข้อมูลจากไฟล์ต้นฉบับมาใส่ buffer ทีละ 8 ไบต์
; ส่งคืน: EAX = จำนวนไบต์ที่อ่านได้จริง (ถ้าเป็น 0 คือจบไฟล์)
; ---------------------------------------------------------
ReadBlock PROC C
    mov eax, inHandle
    mov edx, OFFSET buffer
    mov ecx, 8              ; บอก OS ว่าขอตักข้อมูล 8 ไบต์
    call ReadFromFile
    
    mov bytesRead, eax      ; บันทึกไว้ว่าตักขึ้นมาได้กี่ไบต์ (ถ้า < 8 แปลว่าใกล้จบไฟล์)
    ret
ReadBlock ENDP

; ---------------------------------------------------------
; WriteBlock: นำข้อมูล 8 ไบต์จาก buffer เขียนลงไฟล์ปลายทาง
; ---------------------------------------------------------
WriteBlock PROC C
    mov eax, outHandle
    mov edx, OFFSET buffer
    mov ecx, 8              ; สั่งเขียน 8 ไบต์ลงไฟล์
    call WriteToFile
    ret
WriteBlock ENDP

; ---------------------------------------------------------
; DumpProc: แสดงผลไฟล์ในรูปแบบ Hex และ ASCII
; รับค่า: ESI = Address ของชื่อไฟล์
; ---------------------------------------------------------
DumpProc PROC C
    ; 1. เปิดไฟล์สำหรับอ่าน
    mov edx, esi
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    jne DumpFileOpened
    mov edx, OFFSET errOpenMsg
    call WriteString
    ret

DumpFileOpened:
    mov dumpFileHandle, eax
    mov currentOffset, 0
    
    mov edx, OFFSET dumpHeaderMsg
    call WriteString

DumpReadLoop:
    ; ล้าง Buffer ก่อนอ่านใหม่
    mov edi, OFFSET dumpBuffer
    mov ecx, 16
    mov al, 0
    rep stosb

    ; อ่านข้อมูลทีละ 16 ไบต์
    mov eax, dumpFileHandle
    mov edx, OFFSET dumpBuffer
    mov ecx, 16
    call ReadFromFile
    mov dumpBytesRead, eax
    
    cmp eax, 0          ; ถ้าอ่านไม่ได้เลย (จบไฟล์)
    je DumpEnd

    ; 2. แสดง Offset (8 หลักฐาน 16)
    mov eax, currentOffset
    call WriteHexB
    mov edx, OFFSET separatorMsg
    call WriteString

    ; 3. แสดงเลขฐาน 16 (Hex) ของแต่ละไบต์
    mov edi, 0
HexPrintLoop:
    cmp edi, dumpBytesRead
    jge PrintHexSpaces  ; ถ้าไบต์หมดก่อนครบ 16 ให้พิมพ์ช่องว่าง

    mov al, BYTE PTR [dumpBuffer + edi]  ; ดึงข้อมูล 1 ไบต์มาใส่ใน AL
    call WriteHexB                       ; เรียกใช้ WriteHexB เพื่อพิมพ์ AL เป็น Hex 2 หลัก
    
    mov edx, OFFSET spaceChar
    call WriteString
    jmp NextHexItem

PrintHexSpaces:
    ; พิมพ์ช่องว่างเผื่อกรณีไฟล์ไม่เต็ม 16 ไบต์ในรอบสุดท้าย
    mov edx, OFFSET spaceChar
    call WriteString
    call WriteString
    call WriteString

NextHexItem:
    inc edi
    cmp edi, 16
    jl HexPrintLoop

    mov edx, OFFSET separatorMsg
    call WriteString

    ; 4. แสดงผลเป็นตัวอักษร ASCII
    mov edi, 0
AsciiPrintLoop:
    cmp edi, dumpBytesRead
    jge AsciiPrintEnd

    movzx eax, BYTE PTR [dumpBuffer + edi]
    
    ; เช็คว่าเป็นอักษรที่พิมพ์ได้หรือไม่ (พิมพ์ได้คือ 32 ถึง 126)
    cmp al, 32
    jl PrintDot
    cmp al, 126
    jg PrintDot
    
    call WriteChar
    jmp NextAsciiItem

PrintDot:
    mov edx, OFFSET dotChar
    call WriteString

NextAsciiItem:
    inc edi
    jmp AsciiPrintLoop

AsciiPrintEnd:
    call Crlf
    
    ; ขยับ Offset ไปบรรทัดต่อไป
    add currentOffset, 16
    jmp DumpReadLoop

DumpEnd:
    mov eax, dumpFileHandle
    call CloseFile
    ret
DumpProc ENDP

; ---------------------------------------------------------
; StatsProc: สแกนไฟล์และแสดง Histogram ความถี่ของแต่ละไบต์
; รับค่า: ESI = Address ของชื่อไฟล์
; ---------------------------------------------------------
; ---------------------------------------------------------
; StatsProc: สแกนไฟล์และแสดง Histogram ความถี่ของแต่ละไบต์
; รับค่า: ESI = Address ของชื่อไฟล์
; ---------------------------------------------------------
StatsProc PROC C
    ; 1. เปิดไฟล์
    mov edx, esi
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    jne StatsFileOpened
    mov edx, OFFSET errOpenMsg
    call WriteString
    ret

StatsFileOpened:
    mov inHandle, eax

    ; 2. ล้างตารางความถี่ให้เป็น 0 ทั้งหมด
    mov edi, OFFSET freqTable
    mov ecx, 256
    xor eax, eax
    rep stosd

StatsReadLoop:
    ; 3. อ่านข้อมูล
    mov eax, inHandle
    mov edx, OFFSET statsBuffer
    mov ecx, 256
    call ReadFromFile
    mov statsBytesRead, eax
    
    cmp eax, 0
    je StatsPrintResult

    ; 4. นับความถี่
    mov ecx, statsBytesRead
    mov edi, 0
CountLoop:
    movzx eax, BYTE PTR [statsBuffer + edi]
    shl eax, 2
    inc DWORD PTR [freqTable + eax]
    inc edi
    loop CountLoop

    jmp StatsReadLoop

StatsPrintResult:
    mov eax, inHandle
    call CloseFile

    mov edx, OFFSET statsHeaderMsg
    call WriteString

    ; 5. แสดงผล
    mov esi, 0
PrintStatsLoop:
    mov eax, esi
    shl eax, 2
    mov ebx, DWORD PTR [freqTable + eax]
    
    cmp ebx, 0
    je SkipPrintStats

    ; พิมพ์ "Hex: "
    mov edx, OFFSET statsItemMsg
    call WriteString
    
    ; พิมพ์ Hex 2 หลัก (ใช้ WriteHexB)
    mov eax, esi
    call WriteHexB
    
    ; พิมพ์ " | Count: "
    mov edx, OFFSET statsCountMsg
    call WriteString
    
    ; พิมพ์ตัวเลขฐาน 10
    mov eax, ebx
    call WriteDec
    call Crlf

SkipPrintStats:
    inc esi
    cmp esi, 256
    jl PrintStatsLoop

    ret
StatsProc ENDP

END