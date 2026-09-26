INCLUDE Irvine32.inc
PUBLIC KeygenProc
PUBLIC Subkeys

.data
    ; --- ตารางมาตรฐาน DES ---
    PC1 BYTE 57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18
        BYTE 10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36
        BYTE 63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22
        BYTE 14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4

    PC2 BYTE 14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10, 23, 19, 12, 4
        BYTE 26, 8, 16, 7, 27, 20, 13, 2, 41, 52, 31, 37, 47, 55, 30, 40
        BYTE 51, 45, 33, 48, 44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32

    ShiftTable BYTE 1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1

    ; --- ตัวแปรสำหรับจัดการหน่วยความจำ ---
    keygenStartMsg BYTE "Generating 16 Subkeys...", 0dh, 0ah, 0
    keyMsg         BYTE "K", 0
    colonMsg       BYTE ": ", 0
    noKeyMsg       BYTE "Error: Key parameter missing.", 0dh, 0ah, 0

    KeyL     DWORD ?    ; เก็บ 32 bits ซ้ายต้นฉบับ
    KeyR     DWORD ?    ; เก็บ 32 bits ขวาต้นฉบับ
    Reg_C    DWORD ?    ; ซีก C (28 bits)
    Reg_D    DWORD ?    ; ซีก D (28 bits)
    RoundNum DWORD 0    ; ตัวนับรอบ (0-15)

    Subkeys DWORD 32 DUP(0)    ; เก็บ Subkey 16 รอบ (รอบละ 2 ช่อง = 16 bits บน, 32 bits ล่าง)

.code
KeygenProc PROC
    push ebp
    mov ebp, esp
    pushad

    cmp esi, 0
    je MissingKey

    mov edx, OFFSET keygenStartMsg
    call WriteString

    ; --- 1. โหลดคีย์ 64 bits ---
    mov eax, DWORD PTR [esi]
    bswap eax
    mov KeyL, eax
    
    mov eax, DWORD PTR [esi+4]
    bswap eax
    mov KeyR, eax

    ; --- 2. ทำ PC-1 (ลด 64 เหลือ 56 บิต) ---
    mov esi, OFFSET PC1
    mov edi, 0       
    xor ecx, ecx     ; ECX = ซีก C
    xor edx, edx     ; EDX = ซีก D
        
PC1_Loop:
    movzx eax, BYTE PTR [esi + edi]
    
    ; 1. คำนวณหาตำแหน่งบิต
    cmp eax, 32
    jle UseLeftHalf
        
    mov ebx, 64
    sub ebx, eax      
    mov eax, KeyR
    jmp InsertStep
        
UseLeftHalf:
    mov ebx, 32
    sub ebx, eax      
    mov eax, KeyL
        
InsertStep:
    ; 2. เช็คว่าต้องใส่ซีก C หรือ D (ต้องทำ CMP ก่อน BT เพื่อไม่ให้ทำลายค่า CF)
    cmp edi, 28
    jl InsertC
        
InsertD:
    bt eax, ebx       ; ทดสอบบิต (ผลลัพธ์ไปอยู่ใน CF)
    rcl edx, 1        ; ดูดค่าจาก CF เข้าไปต่อท้าย EDX พร้อมเลื่อนบิตไปทางซ้าย 1 สเต็ป
    jmp NextIterPC1
        
InsertC:
    bt eax, ebx       ; ทดสอบบิต (ผลลัพธ์ไปอยู่ใน CF)
    rcl ecx, 1        ; ดูดค่าจาก CF เข้าไปต่อท้าย ECX พร้อมเลื่อนบิตไปทางซ้าย 1 สเต็ป
        
NextIterPC1:
    inc edi
    cmp edi, 56
    jl PC1_Loop

    ; บันทึกค่าเริ่มต้นของ C และ D
    mov Reg_C, ecx
    mov Reg_D, edx

    ; --- 3. ลูป 16 รอบ สร้าง Subkey ---
    mov RoundNum, 0
Round16_Loop:
    ; โหลดจำนวน Shift (1 หรือ 2) จาก ShiftTable
    mov esi, RoundNum
    movzx eax, BYTE PTR [ShiftTable + esi]

Shift_Loop:
    ; เลื่อนบิต C (28-bit Circular Shift Left)
    mov ecx, Reg_C
    shl ecx, 1
    mov ebx, ecx
    shr ebx, 28
    and ebx, 1
    or ecx, ebx
    and ecx, 0FFFFFFFh
    mov Reg_C, ecx

    ; เลื่อนบิต D (28-bit Circular Shift Left)
    mov edx, Reg_D
    shl edx, 1
    mov ebx, edx
    shr ebx, 28
    and ebx, 1
    or edx, ebx
    and edx, 0FFFFFFFh
    mov Reg_D, edx

    dec eax
    cmp eax, 0
    jg Shift_Loop

    ; --- 4. ทำ PC-2 (ดึง 56 บิต เหลือ 48 บิต) ---
    mov esi, OFFSET PC2
    mov edi, 0       ; ตัวนับลูป PC-2 (0-47)
    xor ecx, ecx     ; ECX = เก็บ 16 บิตแรกของ Subkey
    xor edx, edx     ; EDX = เก็บ 32 บิตหลังของ Subkey

PC2_Loop:
    movzx eax, BYTE PTR [esi + edi]
        
    cmp eax, 28
    jg UseRegD
        
UseRegC:
    mov ebx, 28
    sub ebx, eax
    mov eax, Reg_C
    jmp DoBitTest

UseRegD:
    mov ebx, 56
    sub ebx, eax
    mov eax, Reg_D

DoBitTest:
    ; แก้บั๊กที่ 1: ย้าย CMP มาเช็คเป้าหมายก่อนใช้ BT เพื่อป้องกัน CF โดนล้าง
    cmp edi, 16
    jl InsertToECX
        
InsertToEDX:
    bt eax, ebx       ; ดึงบิต
    rcl edx, 1        ; ยัดบิตลง EDX
    jmp NextPC2

InsertToECX:
    bt eax, ebx       ; ดึงบิต
    rcl ecx, 1        ; ยัดบิตลง ECX

NextPC2:
    inc edi
    cmp edi, 48
    jl PC2_Loop

    ; --- 5. บันทึก Subkey ลง Array ในหน่วยความจำ ---
    mov eax, RoundNum
    shl eax, 3               
    mov DWORD PTR [Subkeys + eax], ecx
    mov DWORD PTR [Subkeys + eax + 4], edx

    ; --- 6. พิมพ์แสดงผล Subkey (48 bits) ---
    push edx                 ; แก้บั๊กที่ 2: ฝากค่าคีย์ 32 บิตล่างไว้ใน Stack ก่อน!

    mov edx, OFFSET keyMsg
    call WriteString
    mov eax, RoundNum
    inc eax
    call WriteDec
    mov edx, OFFSET colonMsg
    call WriteString

    mov eax, ecx
    call WriteHex            ; พิมพ์ 16 บิตบน
    
    pop eax                  ; แก้บั๊กที่ 2: ดึงค่าคีย์คืนจาก Stack มาใส่ EAX ทันทีแล้วพิมพ์
    call WriteHex
    call Crlf

    ; จบรอบ 16 รอบ
    inc RoundNum
    cmp RoundNum, 16
    jl Round16_Loop

    jmp EndKeygen

MissingKey:
    mov edx, OFFSET noKeyMsg
    call WriteString

EndKeygen:
    popad
    mov eax, 1
    pop ebp
    ret
KeygenProc ENDP
END