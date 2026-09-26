# 🔐 DES Encryption Engine (x86 Assembly)

โปรเจคพัฒนาระบบเข้ารหัสและถอดรหัสข้อมูลตามมาตรฐาน **Data Encryption Standard (DES)** โดยเขียนด้วยภาษา **x86 Assembly (MASM)** ระดับ Low-level ทั้งหมด พร้อมระบบจัดการไฟล์ (File I/O) และ Custom CLI Shell สำหรับโต้ตอบกับผู้ใช้งาน

โปรเจคนี้เป็นส่วนหนึ่งของรหัสวิชา 01476105 Computer Organization and Assembly Language Computer Engineering and Cyber Security, KMITL 

## ✨ Features (คุณสมบัติเด่น)

- **Full DES Standard**: รองรับกระบวนการเข้ารหัสครบถ้วนตามมาตรฐานสากล (Initial Permutation, 16-Round Feistel Network, S-Box, P-Box และ IP-1)
- **Symmetric Key Cryptography**: ใช้กุญแจลับขนาด 64-bit (8 ไบต์) ชุดเดียวกันในการล็อกและปลดล็อกข้อมูล
- **File I/O Processing**: สามารถอ่านไฟล์ต้นฉบับและเขียนไฟล์ที่เข้ารหัส/ถอดรหัสแล้วในระดับไบต์ (Block-level ทีละ 8 ไบต์)
- **Auto Zero-Padding**: ระบบจัดการเติมบิต 0 อัตโนมัติ กรณีที่ไฟล์ต้นฉบับมีขนาดไม่หาร 8 ลงตัว
- **Interactive CLI Shell**: หน้าต่างรับคำสั่งแบบ Command Line (`DES-SHELL>`) ที่มีระบบ String Parsing สำหรับแยกคำสั่งและพารามิเตอร์

## 📂 Project Structure (โครงสร้างโค้ด)

โปรเจคนี้ถูกออกแบบด้วยสถาปัตยกรรมแบบ Modular โดยแบ่งการทำงานออกเป็น 4 ไฟล์หลัก เพื่อให้ง่ายต่อการดูแลรักษาและคอมไพล์ข้ามไฟล์ด้วย Calling Convention:

- `main.asm` - จัดการระบบ Interactive Shell, ควบคุม Flow โปรแกรมหลัก และรับคำสั่งจากผู้ใช้
- `des_core.asm` - แกนกลางอัลกอริทึม DES (Feistel Network, Bitwise Permutations)
- `keygen.asm` - ระบบ Key Schedule สำหรับหั่นคีย์หลัก 64-bit เพื่อสร้าง 16 Subkeys
- `utils.asm` - ระบบ File I/O จัดการการเปิด/อ่าน/เขียน/ปิดไฟล์ ผ่าน Windows API ของ Irvine32
- `build.bat` - สคริปต์อัตโนมัติสำหรับ Assemble และ Link โค้ดทั้งหมดเข้าด้วยกัน

## 🛠️ Prerequisites (สิ่งที่ต้องมี)

- ระบบปฏิบัติการ Windows
- **MASM (Microsoft Macro Assembler)** สำหรับคอมไพล์โค้ด
- ไลบรารี **Irvine32** (Irvine32.inc และ Irvine32.lib)

## 🚀 How to Build & Run (วิธีติดตั้งและใช้งาน)

1. Clone หรือดาวน์โหลดโปรเจคนี้ลงเครื่อง
2. รันสคริปต์คอมไพล์ผ่าน Terminal หรือ Command Prompt:
   ```powershell
   .\build.bat
   
   หากคอมไพล์สำเร็จ จะได้ไฟล์ main.exe ให้รันโปรแกรม
   💻 Commands (คำสั่งใน DES-SHELL)
เมื่อเข้าสู่ DES-SHELL> สามารถใช้คำสั่งเหล่านี้ได้:

1. เข้ารหัสไฟล์ (Encrypt)

ENCRYPT <filename> <8-byte-key>
ตัวอย่าง: ENCRYPT dummy.txt JAYLER00
ผลลัพธ์: ระบบจะสร้างไฟล์ที่ถูกเข้ารหัสชื่อ encrypted.bin

2. ถอดรหัสไฟล์ (Decrypt)

DECRYPT <filename> <8-byte-key>
ตัวอย่าง: DECRYPT encrypted.bin JAYLER00
ผลลัพธ์: ระบบจะย้อนกระบวนการด้วย Subkeys แบบถอยหลัง และสร้างไฟล์ผลลัพธ์ชื่อ decrypted.txt

3. คำสั่งอื่นๆ

CLEAR : ล้างหน้าจอ Terminal

EXIT : ออกจากโปรแกรม

👨‍💻 Developer
1.นายกันตพรรธน์ มณีวรรณ 68010067 > Module B: DES Key Schedule Generator (ไฟล์ keygen.asm)
2.นายจิตรนาถ กันทะเอ็ด 68010142 > Module A: Shell Core & FSM Command Parser (ไฟล์ main.asm)
3.นายณัฐวุฒิ พุฒทอง 68010375 > Module D: Memory Dumper & BuƯer Analytics (ไฟล์ utils.asm)
4.นายสุรวิช ภาคีผล 68011179 > Module C: DES 16-Round Feistel Core Engine (ไฟล์ des_core.asm)
