INCLUDE Irvine32.inc
PUBLIC EncryptProc
PUBLIC DecryptProc
EXTERN Subkeys:DWORD   ; <--- เพิ่ม: ดึง Array Subkeys มาจาก keygen.asm
KeygenProc PROTO       ; <--- เพิ่ม: ประกาศว่าจะมีการเรียกใช้ฟังก์ชันจากไฟล์อื่น

; --- เพิ่มตัวแปรและฟังก์ชันจาก utils.asm ---
EXTERN C OpenFiles:PROC
EXTERN C OpenDecFiles:PROC
EXTERN C CloseFiles:PROC
EXTERN C ReadBlock:PROC
EXTERN C WriteBlock:PROC
EXTERN buffer:BYTE
EXTERN bytesRead:DWORD

.data
    ; Initial Permutation (IP)
    IP_Table BYTE 58, 50, 42, 34, 26, 18, 10, 2
             BYTE 60, 52, 44, 36, 28, 20, 12, 4
             BYTE 62, 54, 46, 38, 30, 22, 14, 6
             BYTE 64, 56, 48, 40, 32, 24, 16, 8
             BYTE 57, 49, 41, 33, 25, 17,  9, 1
             BYTE 59, 51, 43, 35, 27, 19, 11, 3
             BYTE 61, 53, 45, 37, 29, 21, 13, 5
             BYTE 63, 55, 47, 39, 31, 23, 15, 7

    encryptMsg BYTE "Encrypting File...", 0dh, 0ah, 0

    ; ข้อมูลจำลอง 64 บิตสำหรับการทดสอบ (เช่น รหัส Hex: 01234567 89ABCDEF)
    DataL DWORD 01234567h
    DataR DWORD 89ABCDEFh
    
    Reg_L DWORD ?      ; เก็บ 32 บิตซีกซ้าย (L0)
    Reg_R DWORD ?      ; เก็บ 32 บิตซีกขวา (R0)
    
    ipMsg BYTE "Initial Permutation (IP) Result:", 0dh, 0ah, "L0: ", 0
    r0Msg BYTE " R0: ", 0

; ตาราง Expansion (E): ขยาย 32 บิต เป็น 48 บิต
    E_Table BYTE 32,  1,  2,  3,  4,  5
            BYTE  4,  5,  6,  7,  8,  9
            BYTE  8,  9, 10, 11, 12, 13
            BYTE 12, 13, 14, 15, 16, 17
            BYTE 16, 17, 18, 19, 20, 21
            BYTE 20, 21, 22, 23, 24, 25
            BYTE 24, 25, 26, 27, 28, 29
            BYTE 28, 29, 30, 31, 32,  1

    Exp_L DWORD ?      ; เก็บ 16 บิตแรกของ R ที่ขยายแล้ว
    Exp_R DWORD ?      ; เก็บ 32 บิตหลังของ R ที่ขยายแล้ว
    expMsg BYTE "Expansion (E) Result: ", 0
    xorMsg BYTE "XOR with Subkey 1 Result: ", 0

    ; ตาราง S-Box ทั้ง 8 กล่อง (กล่องละ 64 ค่า) เรียงต่อกันเป็น Array เดียวเพื่อให้อ่านค่าง่าย
    S_Boxes BYTE 14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7
            BYTE 0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8
            BYTE 4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0
            BYTE 15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13

            BYTE 15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10
            BYTE 3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5
            BYTE 0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15
            BYTE 13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9

            BYTE 10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8
            BYTE 13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1
            BYTE 13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7
            BYTE 1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12

            BYTE 7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15
            BYTE 13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9
            BYTE 10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4
            BYTE 3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14

            BYTE 2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9
            BYTE 14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6
            BYTE 4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14
            BYTE 11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3

            BYTE 12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11
            BYTE 10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8
            BYTE 9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6
            BYTE 4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13

            BYTE 4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1
            BYTE 13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6
            BYTE 1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2
            BYTE 6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12

            BYTE 13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7
            BYTE 1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2
            BYTE 7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8
            BYTE 2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11

    ; ตัวแปรสำหรับรับผลลัพธ์ S-Box และข้อความ
    SBox_Out DWORD 0    ; เก็บผลลัพธ์ 32 บิตที่ผ่านกล่อง S-Box แล้ว
    sboxMsg BYTE "S-Box Output (32-bit): ", 0

    ; --- ตาราง Permutation (P) สำหรับสลับบิตหลังผ่าน S-Box ---
    P_Table BYTE 16,  7, 20, 21, 29, 12, 28, 17
            BYTE  1, 15, 23, 26,  5, 18, 31, 10
            BYTE  2,  8, 24, 14, 32, 27,  3,  9
            BYTE 19, 13, 30,  6, 22, 11,  4, 25

    Reg_P DWORD 0       ; เก็บผลลัพธ์หลังผ่าน P-Box
    pMsg BYTE "P-Box Output: ", 0
    roundEndMsg BYTE "--- End of Round 16 ---", 0dh, 0ah, "L1: ", 0
    r1Msg BYTE " R1: ", 0

    ; --- ตาราง Final Permutation (IP-1) ---
    IP_1_Table BYTE 40, 8, 48, 16, 56, 24, 64, 32
               BYTE 39, 7, 47, 15, 55, 23, 63, 31
               BYTE 38, 6, 46, 14, 54, 22, 62, 30
               BYTE 37, 5, 45, 13, 53, 21, 61, 29
               BYTE 36, 4, 44, 12, 52, 20, 60, 28
               BYTE 35, 3, 43, 11, 51, 19, 59, 27
               BYTE 34, 2, 42, 10, 50, 18, 58, 26
               BYTE 33, 1, 41,  9, 49, 17, 57, 25

    Cipher_L DWORD 0     ; เก็บ Ciphertext 32 บิตซ้าย
    Cipher_R DWORD 0     ; เก็บ Ciphertext 32 บิตขวา
    cipherMsg BYTE "Final Ciphertext (Hex): ", 0

    decryptMsg BYTE "Decrypting File...", 0dh, 0ah, 0

.code
EncryptProc PROC
    push ebp
    mov ebp, esp
    pushad

    mov edx, OFFSET encryptMsg
    call WriteString

    ; --- 0. สร้าง Subkeys เตรียมไว้ ---
    push esi
    mov esi, edi
    call KeygenProc
    pop esi

    ; --- 1. เปิดไฟล์อ่านและสร้างไฟล์เขียน ---
    mov edx, esi            ; EDX รับชื่อไฟล์มาจาก ESI
    call OpenFiles
    cmp eax, 0
    je EndEncrypt           ; ถ้าเปิดไฟล์ไม่สำเร็จ ให้จบการทำงานทันที

ProcessFileLoop:
    ; ล้างค่า buffer เก่าทิ้ง ป้องกันข้อมูลขยะในรอบสุดท้าย
    mov DWORD PTR [buffer], 0
    mov DWORD PTR [buffer + 4], 0

    ; --- 2. อ่านข้อมูลมา 8 ไบต์ ---
    call ReadBlock
    cmp bytesRead, 0
    je FinishFile           ; ถ้าอ่านไม่ได้เลย (EOF) ออกจากลูปไปปิดไฟล์

    ; ดึงข้อมูลจาก buffer เข้าตัวแปร (ใช้ bswap เพื่อแก้ปัญหา Endian ของ x86)
    mov eax, DWORD PTR [buffer]
    bswap eax
    mov DataL, eax
    
    mov eax, DWORD PTR [buffer + 4]
    bswap eax
    mov DataR, eax

    ; ================== เริ่มแกนกลาง DES ==================
    ; 1. Initial Permutation (IP)
    mov esi, OFFSET IP_Table
    mov edi, 0       
    xor ecx, ecx     
    xor edx, edx     
IP_Loop:
    movzx eax, BYTE PTR [esi + edi]
    cmp eax, 32
    jg UseDataR
UseDataL:
    mov ebx, 32
    sub ebx, eax
    mov eax, DataL
    jmp IP_DoBitTest
UseDataR:
    mov ebx, 64
    sub ebx, eax
    mov eax, DataR
IP_DoBitTest:
    cmp edi, 32
    jl InsertToRegL
InsertToRegR:
    bt eax, ebx       
    rcl edx, 1        
    jmp NextIP
InsertToRegL:
    bt eax, ebx       
    rcl ecx, 1        
NextIP:
    inc edi
    cmp edi, 64
    jl IP_Loop
    mov Reg_L, ecx
    mov Reg_R, edx

    ; 2. ลูป 16 รอบ Feistel Network
    push ebp            
    mov ebp, 0          
Round16_Start:
    ; Expansion (E)
    mov esi, OFFSET E_Table
    mov edi, 0       
    xor ecx, ecx     
    xor edx, edx     
Exp_Loop:
    movzx eax, BYTE PTR [esi + edi]
    mov ebx, 32
    sub ebx, eax
    mov eax, Reg_R
    cmp edi, 16
    jl InsertToExpC
InsertToExpD:
    bt eax, ebx       
    rcl edx, 1
    jmp NextExp
InsertToExpC:
    bt eax, ebx       
    rcl ecx, 1
NextExp:
    inc edi
    cmp edi, 48
    jl Exp_Loop
    mov Exp_L, ecx
    mov Exp_R, edx

    ; XOR Subkey
    mov eax, ebp
    shl eax, 3          
    mov ecx, Exp_L
    xor ecx, DWORD PTR [Subkeys + eax]
    mov edx, Exp_R
    xor edx, DWORD PTR [Subkeys + eax + 4]

    ; S-Box
    shl ecx, 16      
    mov edi, 0       
    mov SBox_Out, 0  
SBox_MainLoop:
    mov eax, 0       
    mov esi, 6       
Extract6_Loop:
    shl edx, 1       
    rcl ecx, 1       
    rcl eax, 1       
    dec esi
    cmp esi, 0
    jg Extract6_Loop
    
    mov ebx, eax
    and ebx, 20h     
    mov esi, eax
    and esi, 01h     
    shl esi, 4       
    or ebx, esi      
    mov esi, eax
    and esi, 1Eh     
    shr esi, 1       
    or ebx, esi      
    
    mov eax, edi     
    shl eax, 6       
    add ebx, eax     
    movzx eax, BYTE PTR [S_Boxes + ebx]
    
    mov ebx, SBox_Out
    shl ebx, 4       
    or ebx, eax
    mov SBox_Out, ebx
    
    inc edi          
    cmp edi, 8
    jl SBox_MainLoop

    ; P-Box
    mov esi, OFFSET P_Table
    mov edi, 0
    xor ecx, ecx     
P_Loop:
    movzx eax, BYTE PTR [esi + edi]
    mov ebx, 32
    sub ebx, eax
    mov eax, SBox_Out
    bt eax, ebx      
    rcl ecx, 1       
    inc edi
    cmp edi, 32
    jl P_Loop
    mov Reg_P, ecx

    ; Swap (ถ้ารอบ < 16)
    mov eax, Reg_L      
    xor eax, Reg_P      
    mov ebx, Reg_R      
    cmp ebp, 15
    je FinalRoundNoSwap
    
    mov Reg_L, ebx      
    mov Reg_R, eax      
    jmp EndOfRoundCheck
FinalRoundNoSwap:
    mov Reg_L, eax
    mov Reg_R, ebx
EndOfRoundCheck:
    inc ebp
    cmp ebp, 16
    jl Round16_Start
    pop ebp             

    ; 3. Final Permutation (IP-1)
    mov esi, OFFSET IP_1_Table
    mov edi, 0
    xor ecx, ecx     
    xor edx, edx     
IP1_Loop:
    movzx eax, BYTE PTR [esi + edi]
    cmp eax, 32
    jg UseRegR16
UseRegL16:
    mov ebx, 32
    sub ebx, eax
    mov eax, Reg_L
    jmp IP1_DoBitTest
UseRegR16:
    mov ebx, 64
    sub ebx, eax
    mov eax, Reg_R
IP1_DoBitTest:
    cmp edi, 32
    jl InsertToCipherL
InsertToCipherR:
    bt eax, ebx
    rcl edx, 1
    jmp NextIP1
InsertToCipherL:
    bt eax, ebx
    rcl ecx, 1
NextIP1:
    inc edi
    cmp edi, 64
    jl IP1_Loop
    mov Cipher_L, ecx
    mov Cipher_R, edx
    ; ================== จบแกนกลาง DES ==================

    ; นำ Ciphertext ใส่กลับลง buffer เพื่อเตรียมเขียน (ใช้ bswap สลับ Endian กลับ)
    mov eax, Cipher_L
    bswap eax
    mov DWORD PTR [buffer], eax
    
    mov eax, Cipher_R
    bswap eax
    mov DWORD PTR [buffer + 4], eax

    ; --- 3. เขียน 8 ไบต์ที่เข้ารหัสแล้วลงไฟล์ ---
    call WriteBlock
    jmp ProcessFileLoop     ; วนกลับไปอ่าน 8 ไบต์ถัดไป!

FinishFile:
    ; --- 4. ปิดไฟล์เมื่ออ่านจนหมด ---
    call CloseFiles

EndEncrypt:
    popad
    mov eax, 1
    pop ebp
    ret
EncryptProc ENDP

DecryptProc PROC
    push ebp
    mov ebp, esp
    pushad

    mov edx, OFFSET decryptMsg
    call WriteString

    push esi
    mov esi, edi
    call KeygenProc
    pop esi

    ; --- เรียกฟังก์ชันเปิดไฟล์สำหรับ Decrypt (สร้าง decrypted.txt) ---
    mov edx, esi            
    call OpenDecFiles
    cmp eax, 0
    je EndDecrypt           

ProcessDecFileLoop:
    mov DWORD PTR [buffer], 0
    mov DWORD PTR [buffer + 4], 0

    call ReadBlock
    cmp bytesRead, 0
    je FinishDecFile           

    mov eax, DWORD PTR [buffer]
    bswap eax
    mov DataL, eax
    
    mov eax, DWORD PTR [buffer + 4]
    bswap eax
    mov DataR, eax

    ; 1. Initial Permutation (IP)
    mov esi, OFFSET IP_Table
    mov edi, 0       
    xor ecx, ecx     
    xor edx, edx     
DecIP_Loop:
    movzx eax, BYTE PTR [esi + edi]
    cmp eax, 32
    jg DecUseDataR
DecUseDataL:
    mov ebx, 32
    sub ebx, eax
    mov eax, DataL
    jmp DecIP_DoBitTest
DecUseDataR:
    mov ebx, 64
    sub ebx, eax
    mov eax, DataR
DecIP_DoBitTest:
    cmp edi, 32
    jl DecInsertToRegL
DecInsertToRegR:
    bt eax, ebx       
    rcl edx, 1        
    jmp DecNextIP
DecInsertToRegL:
    bt eax, ebx       
    rcl ecx, 1        
DecNextIP:
    inc edi
    cmp edi, 64
    jl DecIP_Loop
    mov Reg_L, ecx
    mov Reg_R, edx

    ; 2. ลูป 16 รอบ Feistel Network
    push ebp            
    mov ebp, 0          
DecRound16_Start:
    ; Expansion (E)
    mov esi, OFFSET E_Table
    mov edi, 0       
    xor ecx, ecx     
    xor edx, edx     
DecExp_Loop:
    movzx eax, BYTE PTR [esi + edi]
    mov ebx, 32
    sub ebx, eax
    mov eax, Reg_R
    cmp edi, 16
    jl DecInsertToExpC
DecInsertToExpD:
    bt eax, ebx       
    rcl edx, 1
    jmp DecNextExp
DecInsertToExpC:
    bt eax, ebx       
    rcl ecx, 1
DecNextExp:
    inc edi
    cmp edi, 48
    jl DecExp_Loop
    mov Exp_L, ecx
    mov Exp_R, edx

    ; --- [จุดสำคัญ]: XOR Subkey แบบถอยหลัง (K16 -> K1) ---
    mov eax, 15
    sub eax, ebp        ; EAX = 15 - EBP (ถ้า EBP=0 ได้ 15, ถ้า EBP=15 ได้ 0)
    shl eax, 3          ; คูณ 8 เพื่อหา Index
    
    mov ecx, Exp_L
    xor ecx, DWORD PTR [Subkeys + eax]
    mov edx, Exp_R
    xor edx, DWORD PTR [Subkeys + eax + 4]

    ; S-Box
    shl ecx, 16      
    mov edi, 0       
    mov SBox_Out, 0  
DecSBox_MainLoop:
    mov eax, 0       
    mov esi, 6       
DecExtract6_Loop:
    shl edx, 1       
    rcl ecx, 1       
    rcl eax, 1       
    dec esi
    cmp esi, 0
    jg DecExtract6_Loop
    
    mov ebx, eax
    and ebx, 20h     
    mov esi, eax
    and esi, 01h     
    shl esi, 4       
    or ebx, esi      
    mov esi, eax
    and esi, 1Eh     
    shr esi, 1       
    or ebx, esi      
    
    mov eax, edi     
    shl eax, 6       
    add ebx, eax     
    movzx eax, BYTE PTR [S_Boxes + ebx]
    
    mov ebx, SBox_Out
    shl ebx, 4       
    or ebx, eax
    mov SBox_Out, ebx
    
    inc edi          
    cmp edi, 8
    jl DecSBox_MainLoop

    ; P-Box
    mov esi, OFFSET P_Table
    mov edi, 0
    xor ecx, ecx     
DecP_Loop:
    movzx eax, BYTE PTR [esi + edi]
    mov ebx, 32
    sub ebx, eax
    mov eax, SBox_Out
    bt eax, ebx      
    rcl ecx, 1       
    inc edi
    cmp edi, 32
    jl DecP_Loop
    mov Reg_P, ecx

    ; Swap (ถ้ารอบ < 16)
    mov eax, Reg_L      
    xor eax, Reg_P      
    mov ebx, Reg_R      
    cmp ebp, 15
    je DecFinalRoundNoSwap
    
    mov Reg_L, ebx      
    mov Reg_R, eax      
    jmp DecEndOfRoundCheck
DecFinalRoundNoSwap:
    mov Reg_L, eax
    mov Reg_R, ebx
DecEndOfRoundCheck:
    inc ebp
    cmp ebp, 16
    jl DecRound16_Start
    pop ebp             

    ; 3. Final Permutation (IP-1)
    mov esi, OFFSET IP_1_Table
    mov edi, 0
    xor ecx, ecx     
    xor edx, edx     
DecIP1_Loop:
    movzx eax, BYTE PTR [esi + edi]
    cmp eax, 32
    jg DecUseRegR16
DecUseRegL16:
    mov ebx, 32
    sub ebx, eax
    mov eax, Reg_L
    jmp DecIP1_DoBitTest
DecUseRegR16:
    mov ebx, 64
    sub ebx, eax
    mov eax, Reg_R
DecIP1_DoBitTest:
    cmp edi, 32
    jl DecInsertToCipherL
DecInsertToCipherR:
    bt eax, ebx
    rcl edx, 1
    jmp DecNextIP1
DecInsertToCipherL:
    bt eax, ebx
    rcl ecx, 1
DecNextIP1:
    inc edi
    cmp edi, 64
    jl DecIP1_Loop
    mov Cipher_L, ecx
    mov Cipher_R, edx

    ; สลับ Endian กลับแล้วนำใส่ buffer เตรียมเขียนลงไฟล์
    mov eax, Cipher_L
    bswap eax
    mov DWORD PTR [buffer], eax
    
    mov eax, Cipher_R
    bswap eax
    mov DWORD PTR [buffer + 4], eax

    call WriteBlock
    jmp ProcessDecFileLoop     

FinishDecFile:
    call CloseFiles

EndDecrypt:
    popad
    mov eax, 1
    pop ebp
    ret
DecryptProc ENDP
END