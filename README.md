# Morse Code to ASCII Decoder & Micro-Programmed Control Unit

Project ini adalah implementasi desain sistem digital menggunakan VHDL yang terdiri dari dua modul utama: **Morse to ASCII Decoder** dan **Micro-Programmed Control Unit**. Project ini dirancang sebagai bagian dari Tugas Akhir mata kuliah Perancangan Sistem Digital (PSD).

## 📋 Deskripsi Project

Sistem ini dirancang untuk:
1.  **Menerima sinyal Morse serial** (titik dan garis) melalui input satu bit.
2.  **Mengukur durasi sinyal** menggunakan *Finite State Machine* (FSM) dan counter.
3.  **Mengonversi pola Morse** menjadi karakter ASCII 8-bit yang sesuai.
4.  **Mengendalikan alur data** menggunakan *Control Unit* berbasis instruksi mikro (Micro-programmed).

## 🛠️ Struktur File

* `morse_decoder.vhd`: Modul utama decoder morse. Berisi logika FSM, counter durasi, dan shift register untuk pengenalan pola.
* `control_unit.vhd`: Unit kendali prosesor sederhana berbasis ROM (Control Store) yang memetakan *Opcode* ke sinyal kontrol (*Control Signals*).
* `testbench.vhd`: File simulasi (testbench) untuk memverifikasi fungsionalitas decoder dengan mengirimkan stimulus sinyal morse.

## ⚙️ Cara Kerja (Technical Implementation)

### 1. Morse Decoder Logic
Decoder ini menggunakan pendekatan *Shift Register* dengan *encoding* internal yang unik untuk membedakan Dot dan Dash dalam satu register.

* **Logika Sinyal:**
    * `'1'` (High): Menandakan penekanan tombol (sinyal aktif).
    * `'0'` (Low): Menandakan spasi/jeda.

* **Threshold Waktu:**
    * **Dot (.):** Durasi High < `THRESH_DASH` (2 unit).
    * **Dash (-):** Durasi High >= `THRESH_DASH` (2 unit).
    * **Akhir Simbol:** Durasi Low pendek (transisi antar simbol).
    * **Akhir Karakter:** Durasi Low = `THRESH_CHAR_END` (3 unit).
    * **Spasi (Akhir Kata):** Durasi Low = `THRESH_SPACE` (7 unit).

* **Mekanisme Shift Register (Input Buffer):**
    Sistem menyimpan riwayat sinyal ke dalam `shiftreg_inb` (10-bit) dengan aturan:
    1.  Jika terdeteksi **Dot**, geser masuk bit `'1'`.
    2.  Jika terdeteksi **Dash**, geser masuk bit string `"11"`.
    3.  Saat jeda antar simbol selesai, geser masuk bit `'0'` sebagai pemisah.

    *Contoh:* Huruf **'A'** (`.-`) akan tersimpan di register sebagai `...01011` (1=Dot, 0=Spasi, 11=Dash).

### 2. Micro-Programmed Control Unit
Modul ini bertindak sebagai otak eksekusi yang mengambil instruksi makro dan menerjemahkannya menjadi sinyal kontrol hardware.

* **Arsitektur:** Menggunakan **Control Store (ROM)** berukuran 256 baris.
* **Instruksi yang Didukung:** `LDA`, `STA`, `ADD`, `SUB`, `JMP`, `CMP`, `HLT`, dll.
* **Sequencing:** Mendukung `SEQ_NEXT`, `SEQ_FETCH`, `SEQ_DECODE`, dan `SEQ_HLT`.

## 👥 Authors

Project ini dikerjakan oleh kelompok yang beranggotakan:

| No. | Nama Anggota | NPM |
| :--- | :--- | :--- |
| 1. | [Nama Anggota 1] | [NPM 1] |
| 2. | [Nama Anggota 2] | [NPM 2] |
| 3. | [Nama Anggota 3] | [NPM 3] |
| 4. | [Nama Anggota 4] | [NPM 4] |

---
