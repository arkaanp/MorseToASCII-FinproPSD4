# Morse Code to ASCII Decoder & Micro-Programmed Control Unit

Project ini adalah implementasi desain sistem digital menggunakan VHDL yang terdiri dari dua modul utama: **Morse to ASCII Decoder** dan **Micro-Programmed Control Unit**. Project ini dirancang sebagai bagian dari Tugas Akhir mata kuliah Perancangan Sistem Digital (PSD).

## 📋 Deskripsi Project

Sistem ini dirancang untuk:
1.  **Menerima sinyal Morse serial** (titik dan garis) melalui input satu bit.
2.  **Mengukur durasi sinyal** menggunakan *Finite State Machine* (FSM) dan counter.
3.  **Mengonversi pola Morse** menjadi karakter ASCII 8-bit yang sesuai.
4.  **Mengendalikan alur data** menggunakan *Control Unit* berbasis instruksi mikro (Micro-programmed).

## 🛠️ Struktur File

* `morse_decoder.vhd`: Berisi Unit Data (Datapath), termasuk counter durasi, shift register, dan logika eksekusi (seperti shifting dan padding), yang diatur oleh control signals dari control_unit.vhd.
* `control_unit.vhd`: mengimplementasikan Microprogrammed Control Unit yang menggunakan memori ROM (Control Store) untuk menyimpan microinstructions guna menentukan status FSM berikutnya dan menghasilkan control signals untuk mengendalikan morse_decoder.vhd.
* `testbench.vhd`: File simulasi (testbench) untuk memverifikasi fungsionalitas decoder dengan mengirimkan stimulus sinyal morse.

## ⚙️ Cara Kerja (Technical Implementation)

### 1. Morse Decoder Logic (morse_decoder.vhd)
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

    *Contoh:* Huruf 'A' (.-) akan tersimpan di register sebagai `"...01011"`. Pola yang dicari untuk di-decode adalah `"1011"` yang disejajarkan ke kanan, misalnya `"0000001011"`.

### 2. Micro-Programmed Control Unit (control_unit.vhd)
Modul ini bertindak sebagai otak eksekusi yang menggunakan **Microprogrammed FSM** untuk menentukan status dekoder Morse berikutnya dan menghasilkan sinyal kontrol hardware yang spesifik.

* **Arsitektur:** Menggunakan Control Store (ROM) berukuran 16 baris yang menyimpan Microinstructions (20-bit, 3-bit Sequencing + 7-bit Control Signals).
* **Instruksi Mikro (Control Signals) yang Dikeluarkan:** * `ctrl_clr_all`: Mereset *counter* (`counter_one` dan `counter_zero`).
    * `ctrl_inc_one`: Menambah `counter_one` (mengukur durasi Pulse/DOT/DASH).
    * `ctrl_inc_zero`: Menambah `counter_zero` (mengukur durasi Gap/Pemisah).
    * `ctrl_proc_pulse`: Memicu pemrosesan Pulse (Dot/Dash) dan memuat hasilnya ke *shift register*.
    * `ctrl_proc_gap`: Memicu pemrosesan Gap (Pemisah simbol) dan memuat bit '0' ke *shift register*.
    * `ctrl_dec_char`: Mengaktifkan dekode Character (pembacaan *shift register* dan output ASCII).
    * `ctrl_dec_space`: Mengaktifkan output ASCII untuk Spasi (`x"20"`).
* **Sequencing (Perintah FSM/ROM) yang Didukung:**
    * `SEQ_NEXT`: Pindah ke instruksi berikutnya (`uPC + 1`).
    * `SEQ_JMP_HIGH`: Lompat jika input Morse adalah '1' (untuk transisi dari IDLE).
    * `SEQ_CHK_FALL`: Periksa transisi `morse_in` dari '1' ke '0' (akhir Pulse).
    * `SEQ_CHK_RISE`: Periksa transisi `morse_in` dari '0' ke '1' (akhir Gap).
    * `SEQ_GOTO_IDLE`: Lompat kembali ke alamat 0 (IDLE).
    * `SEQ_GOTO_LOW`: Lompat kembali ke alamat 4 (Main Low Loop).

## 👥 Authors

Project ini dikerjakan oleh kelompok yang beranggotakan:

| No. | Nama Anggota | NPM |
| :--- | :--- | :--- |
| 1. | Arkaan Pasya Seplitara | 2406408073 |
| 2. | Qais Ismail | 2406487090 |
| 3. | Danish Al Fayyadh Sunarta | 2406416951 |
| 4. | Raihan Muhammad Nafis Al-Kautsar | 2406413451 |

---
