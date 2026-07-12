# Codex Status Settings, Login, and Icon — Design Specification

## Goal

ขยาย Codex Status ให้มี app icon ที่จดจำได้, Menu Bar item แบบประหยัดพื้นที่, หน้าต่าง Settings และ flow เข้าสู่ระบบที่ใช้บัญชี Codex ทางการในเครื่องโดยไม่รับหรือจัดเก็บ credential เอง

## Account and Login

- ตรวจสถานะการเข้าสู่ระบบจาก metadata ใน `~/.codex/auth.json` แบบ read-only โดย decode เฉพาะข้อมูลที่ไม่เป็นความลับ
- ห้ามอ่าน, แสดง, log หรือคัดลอก access token, refresh token, API key และ credential อื่น
- สถานะมี `ตรวจสอบอยู่`, `เข้าสู่ระบบแล้ว`, `ยังไม่ได้เข้าสู่ระบบ` และ `ตรวจสอบไม่ได้`
- ปุ่ม `เข้าสู่ระบบด้วย Codex` เรียก executable `codex login` ที่ติดตั้งอยู่ในเครื่อง ซึ่งเป็นเจ้าของ browser-based authentication flow
- หากไม่พบ `codex` ให้เปิด Codex Desktop และแสดงคำแนะนำใน Settings
- หลังเริ่ม login ให้ตรวจสถานะใหม่เป็นระยะและอัปเดต UI เมื่อบัญชีพร้อม
- ปุ่ม `เปิด Codex` เปิดแอป Codex Desktop ที่ติดตั้งอยู่

## Menu Bar

- ใช้รูปแบบกะทัดรัด `icon + 72%` เพื่อหลีกเลี่ยงพื้นที่ notch
- รองรับตัวเลือก `icon + percentage`, `percentage only`, และ `icon only`
- สีเขียวเมื่อเหลือมากกว่า 50%, เหลืองเมื่อเหลือ 20–50%, แดงเมื่อต่ำกว่า threshold ที่ผู้ใช้ตั้งค่า (ค่าเริ่มต้น 20%), เทาเมื่อไม่มีข้อมูล
- จุดหรือสี accent แสดงสถานะ idle, working, completed และ failed
- Popover เดิมยังแสดง quota windows, reset time, activity, stale/error state, refresh และ quit
- เพิ่มปุ่ม Settings และ account status ใน Popover

## Settings Window

Settings เป็นหน้าต่าง Native แยกจาก Popover และเปิดซ้ำโดย reuse หน้าต่างเดิม

### Account

- แสดงสถานะการเข้าสู่ระบบ
- แสดงประเภทบัญชีหรือ plan เฉพาะเมื่อ metadata ที่ไม่เป็นความลับมีค่า
- ปุ่ม `เข้าสู่ระบบด้วย Codex` และ `เปิด Codex`
- แสดงข้อความ privacy ว่าแอปไม่เข้าถึง token

### Display

- เลือกรูปแบบ Menu Bar สามแบบ
- เปิด/ปิดการใช้สีตามโควตา
- threshold สีแดง 5–40% ค่าเริ่มต้น 20%
- เปิด/ปิดสถานะงานบน Menu Bar

### General

- เปิดพร้อม login ของ macOS ผ่าน `SMAppService` เมื่อ bundle รองรับ และแสดง error โดยไม่คาดเดา
- refresh interval 15, 30 หรือ 60 วินาที
- แสดง path `~/.codex/sessions`
- ปุ่มตรวจสอบข้อมูล, เวอร์ชัน และ build

ค่าตั้งเก็บด้วย `UserDefaults` ใน bundle domain ของแอปและไม่รวมข้อมูลลับ

## Icon

- app icon เป็นตัว `C` สีขาวในวงแหวน gauge สีเขียว–ฟ้า บนพื้นเข้มแบบ macOS
- ต้องอ่านได้ที่ 16px และไม่ใช้รายละเอียดเล็กเกินไป
- ส่งออก `AppIcon.icns` พร้อม PNG master และใช้ icon เดียวกันเป็นสัญลักษณ์ Menu Bar แบบย่อ
- Menu Bar asset ต้องมี contrast ที่ดีทั้ง Light และ Dark appearance

## Architecture

- `CodexAccountProvider`: ตรวจเฉพาะสถานะ auth และเปิด official login flow
- `AppPreferences`: model สำหรับ UserDefaults และ validation ของค่า
- `StatusStore`: รวม quota, activity, account และ preferences พร้อม timer ที่เปลี่ยน interval ได้
- `SettingsView` และ `SettingsWindowController`: หน้าต่าง Settings ที่ reuse ได้
- `StatusCapsuleImage`: render รูปแบบกะทัดรัดตาม preferences
- AppKit shell ยังคงเป็นเจ้าของ `NSStatusItem` และ `NSPopover` เพื่อความเสถียรบน macOS 26

## Error Handling

- ไม่พบ Codex CLI: ไม่เริ่ม shell command อื่นแทนและแสดงคำแนะนำ
- login process ล้มเหลว: แสดง exit status แบบไม่รวม stdout ที่อาจมีข้อมูลละเอียด
- auth schema เปลี่ยน: แสดง `ตรวจสอบไม่ได้` โดยไม่ decode credential fields
- SMAppService ไม่พร้อม: revert toggle และแสดง error
- preference ไม่ถูกต้อง: clamp หรือคืนค่า default

## Verification

- Unit tests ครอบคลุม auth states โดยใช้ fixture ที่ไม่มี token จริง
- Unit tests ยืนยันว่า parser ไม่ต้อง decode credential fields
- Unit tests ครอบคลุม preference defaults, persistence และ threshold clamp
- Unit tests ครอบคลุม menu presentation ทั้งสามรูปแบบ
- Build script ใส่ AppIcon และ `NSPrincipalClass`
- Launch test ยืนยันมี process เพียงหนึ่ง instance
- ตรวจว่า Settings เปิดซ้ำแล้วไม่สร้างหน้าต่างซ้อน
- ตรวจ app bundle, icon asset, login command availability และ Menu Bar item ผ่าน runtime evidence

## Out of Scope

- OAuth implementation ภายในแอป
- ช่องกรอก API key
- การอ่านหรือ export token
- การแก้ quota หรือ subscription
- การส่ง telemetry ออกนอกเครื่อง

