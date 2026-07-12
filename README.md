# Codex Status for macOS

แอป Menu Bar ขนาดเล็กสำหรับแสดงโควตา Codex จริงที่พบใน session metadata และสถานะงานล่าสุดบนเครื่อง

## Build และเปิดใช้งาน

ต้องใช้ macOS 13 ขึ้นไปและ Swift 6:

```bash
./scripts/build-app.sh
open "dist/Codex Status.app"
```

สำหรับ build และเปิดใหม่โดยปิด instance เก่าก่อนเสมอ:

```bash
./script/build_and_run.sh --verify
```

แอปจะปรากฏเป็นแคปซูล `Codex 72%` บน Menu Bar คลิกเพื่อดูโควตาแต่ละรอบ เวลารีเซ็ต สถานะงาน และเวลาอัปเดตล่าสุด

คลิก `ตั้งค่า` หรือไอคอนเฟืองเพื่อเปิดหน้าต่าง Settings สำหรับบัญชี Codex, รูปแบบ Menu Bar, สีแจ้งเตือน, รอบรีเฟรช และการเปิดพร้อม macOS ปุ่ม `เข้าสู่ระบบด้วย Codex` ใช้ flow ของ Codex ทางการและแอปไม่อ่านหรือจัดเก็บ token

## ความหมายของสี

- เขียว: เหลือมากกว่า 50%
- เหลือง: เหลือ 20–50%
- แดง: เหลือน้อยกว่า 20%
- เทาและ `—`: ไม่พบเปอร์เซ็นต์ที่ตรวจสอบได้

จุดสถานะเป็นสีเทาเมื่อว่าง สีฟ้าเมื่อกำลังทำงาน สีเขียวเมื่องานเสร็จ และสีแดงเมื่อเกิดข้อผิดพลาด

## แหล่งข้อมูลและความเป็นส่วนตัว

แอปอ่านเฉพาะ event metadata ชนิด `token_count`, `task_started`, `task_complete`, `task_failed`, `turn_aborted` และ `error` จาก `~/.codex/sessions/**/*.jsonl` แบบ read-only ไม่อ่านหรือแสดง prompt/response, API key หรือ credential และไม่ส่งข้อมูลออกจากเครื่อง

โควตาที่แสดงคือค่าคงเหลือของหน้าต่างที่ถูกจำกัดมากที่สุด โดยคำนวณจาก `100 - used_percent` หาก Codex เปลี่ยน schema หรือยังไม่สร้าง usage event แอปจะแสดง `Codex —` แทนการประมาณค่า

## ตรวจสอบ

```bash
swift run CodexStatusTests
swift build
./scripts/build-app.sh
./scripts/test-launch.sh
```
