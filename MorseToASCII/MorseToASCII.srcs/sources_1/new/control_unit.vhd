library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Entity tetap sama persis
entity control_unit is
    port (
        CLK             : in std_logic;
        enable          : in std_logic;
        RST             : in std_logic;
        carry_flag      : in std_logic;
        zero_flag       : in std_logic;
        opcode          : in std_logic_vector(3 downto 0);
        control_signals : out std_logic_vector(13 downto 0) -- [RAO,RAI,RBO,RBI,SUB,ALO,PCI,PCO,CNT,MRI,RMI,RMO,IRI,IRO]
    );
end entity control_unit;

architecture rtl_classic_microprogram of control_unit is

    -- ### 1. Definisi Format Micro-Instruction ###
    
    -- Bit sekuensial (seperti di kode hipotetis Anda)
    constant C_CTRL_BITS : integer := 14; -- 14 bit untuk sinyal kontrol
    constant C_SEQ_BITS  : integer := 2;  -- 2 bit untuk sequencing
    constant C_UCODE_WIDTH : integer := C_CTRL_BITS + C_SEQ_BITS; -- Total 16 bit
    
    -- Perintah sequencing
    constant SEQ_NEXT   : std_logic_vector(1 downto 0) := "00"; -- Ambil uPC + 1
    constant SEQ_DECODE : std_logic_vector(1 downto 0) := "01"; -- Lompat berdasarkan opcode
    constant SEQ_FETCH  : std_logic_vector(1 downto 0) := "10"; -- Kembali ke alamat Fetch (0)
    constant SEQ_HLT    : std_logic_vector(1 downto 0) := "11"; -- Berhenti (loop di uPC)

    -- ### 2. Control Store (ROM) ###

    -- Kita butuh uPC yang lebih besar untuk memetakan alamat
    subtype t_uAddress is unsigned(7 downto 0);
    type t_control_store is array(0 to 255) of std_logic_vector(C_UCODE_WIDTH - 1 downto 0);

    -- Helper function untuk membangun micro-instruction
    function to_ucode(
        ctrl : std_logic_vector(C_CTRL_BITS - 1 downto 0);
        seq  : std_logic_vector(C_SEQ_BITS - 1 downto 0)
    ) return std_logic_vector is
    begin
        -- Format: [Seq(1:0), Ctrl(13:0)]
        return seq & ctrl;
    end function;

    -- Alamat untuk Fetch & Alamat "lompat" untuk Opcode 
    constant uADDR_FETCH1 : t_uAddress := "00000000"; -- Alamat 0
    constant uADDR_FETCH2 : t_uAddress := "00000001"; -- Alamat 1
    constant uADDR_FETCH3 : t_uAddress := "00000010"; -- Alamat 2
    
    -- =============TODO: Definisikan konstanta untuk alamat micro-routine setiap instruksi=============
    -- Buat konstanta uADDR untuk setiap instruksi (NOP, LDA, STA, ADD, MAB, LDB, STB, MBA, JMP, CMP, SUB, HLT)
    -- Format: constant uADDR_XXX1 : t_uAddress := "XXXXXXXX";
    -- Contoh: constant uADDR_NOP1 : t_uAddress := "00010000"; -- Opcode 0000 -> alamat 16
    -- Berikan jarak antar alamat untuk instruksi multi-cycle (jarak 2 untuk tiap instruction)
    -- =================================================================================================
    
    constant uADDR_NOP1 : t_uAddress := "00000011"; 
    constant uADDR_NOP2 : t_uAddress := "00000100";
    constant uADDR_LDA1 : t_uAddress := "00000101"; 
    constant uADDR_LDA2 : t_uAddress := "00000110";
    constant uADDR_STA1 : t_uAddress := "00000111"; 
    constant uADDR_STA2 : t_uAddress := "00001000";
    constant uADDR_ADD  : t_uAddress := "00001001";  
    constant uADDR_MAB  : t_uAddress := "00001010";  
    constant uADDR_LDB1 : t_uAddress := "00001011"; 
    constant uADDR_LDB2 : t_uAddress := "00001100";
    constant uADDR_STB1 : t_uAddress := "00001101"; 
    constant uADDR_STB2 : t_uAddress := "00001110";
    constant uADDR_MBA  : t_uAddress := "00001111";  
    constant uADDR_JMP  : t_uAddress := "00010000";  
    constant uADDR_CMP  : t_uAddress := "00010001"; 
    constant uADDR_SUB  : t_uAddress := "00010010";
    constant uADDR_HLT  : t_uAddress := "00010011";
    
    -- Inisialisasi ROM
    function init_rom return t_control_store is
        variable rom : t_control_store := (others => (others => '0'));
        
        -- Konstanta 14-bit untuk sinyal kontrol FETCH (sudah lengkap sebagai contoh)
        constant C_FETCH1 : std_logic_vector(13 downto 0) := "00000001010000"; -- PCO=1, MRI=1
        constant C_FETCH2 : std_logic_vector(13 downto 0) := "00000000000110"; -- RMO=1, IRI=1
        constant C_FETCH3 : std_logic_vector(13 downto 0) := "00000000000110"; -- RMO=1, IRI=1
        
        -- =============TODO: Definisikan konstanta 14-bit untuk sinyal kontrol setiap instruksi=============
        -- 
        -- Format konstanta: constant C_XXX1 : std_logic_vector(13 downto 0) := "XXXXXXXXXXXXXX";
        -- 
        -- Untuk bit Control Wordnya ingat kembali TP dan CS dan pastikan sudah benar
        -- ==================================================================================================

        constant C_LDA1  : std_logic_vector(13 downto 0) := "00000000010001"; 
        constant C_LDA2  : std_logic_vector(13 downto 0) := "01000000100100"; 
        constant C_STA1  : std_logic_vector(13 downto 0) := "00000000010001"; 
        constant C_STA2  : std_logic_vector(13 downto 0) := "10000000101000"; 
        constant C_LDB1  : std_logic_vector(13 downto 0) := "00000000010001"; 
        constant C_LDB2  : std_logic_vector(13 downto 0) := "00010000100100"; 
        constant C_STB1  : std_logic_vector(13 downto 0) := "00000000010001"; 
        constant C_STB2  : std_logic_vector(13 downto 0) := "00100000101000"; 
        constant C_MAB   : std_logic_vector(13 downto 0) := "10010000100000"; 
        constant C_MBA   : std_logic_vector(13 downto 0) := "01100000100000"; 
        constant C_NOP1  : std_logic_vector(13 downto 0) := "00000000000000"; 
        constant C_NOP2  : std_logic_vector(13 downto 0) := "00000000100000"; 
        constant C_JMP   : std_logic_vector(13 downto 0) := "00000010100001"; 
        constant C_CMP   : std_logic_vector(13 downto 0) := "00001000100000"; 
        constant C_ADD   : std_logic_vector(13 downto 0) := "01000100100000"; 
        constant C_SUB   : std_logic_vector(13 downto 0) := "01001100100000"; 
        constant C_HLT   : std_logic_vector(13 downto 0) := "00000000000000"; 
        
    begin
        -- ### Siklus Fetch (3 cycles) - SORRY INI HARUSNYA BEGINI ###
        rom(to_integer(uADDR_FETCH1)) := to_ucode(C_FETCH1, SEQ_NEXT);   -- CC1: PCO=1, MRI=1 -> lanjut ke FETCH2
        rom(to_integer(uADDR_FETCH2)) := to_ucode(C_FETCH2, SEQ_NEXT);   -- CC2: RMO=1, IRI=1 -> lanjut ke FETCH3
        rom(to_integer(uADDR_FETCH3)) := to_ucode(C_FETCH3, SEQ_DECODE); -- CC3: RMO=1, IRI=1 -> decode opcode
        
        -- ===========TODO: Isi ROM dengan micro-routines untuk setiap instruksi=============
        -- 
        -- Gunakan fungsi to_ucode(control_signal_constant, sequencing_command)
        -- - Parameter 1: Konstanta control signal (misal C_NOP1, C_LDA1, dll)
        -- - Parameter 2: Perintah sequencing (SEQ_NEXT, SEQ_FETCH, SEQ_DECODE, atau SEQ_HLT)
        -- 
        -- Sequencing command menentukan kemana uPC akan melompat setelah cycle ini:
        -- - SEQ_NEXT   : Lanjut ke alamat berikutnya (uPC + 1)
        -- - SEQ_FETCH  : Kembali ke awal FETCH (uADDR_FETCH1)
        -- - SEQ_DECODE : Decode opcode dan lompat ke instruksi yang sesuai
        -- - SEQ_HLT    : Berhenti, tetap di alamat yang sama (loop forever)
        -- 
        -- Ini akan mirip dengan state machine pada modul sebelumnya, tapi di sini kita hanya mengisi ROM
        -- dengan micro-instructions yang sesuai untuk setiap instruksi.
        -- Kalo bingung liat yang fetch kayak gimana ngisinya.
        -- ====================================================================================
        rom(to_integer(uADDR_NOP1)) := to_ucode(C_NOP1, SEQ_NEXT); 
        rom(to_integer(uADDR_NOP2)) := to_ucode(C_NOP2, SEQ_FETCH); 
        
        rom(to_integer(uADDR_LDA1)) := to_ucode(C_LDA1, SEQ_NEXT);   
        rom(to_integer(uADDR_LDA2)) := to_ucode(C_LDA2, SEQ_FETCH);  
        
        rom(to_integer(uADDR_STA1)) := to_ucode(C_STA1, SEQ_NEXT);  
        rom(to_integer(uADDR_STA2)) := to_ucode(C_STA2, SEQ_FETCH);  
        
        rom(to_integer(uADDR_ADD))  := to_ucode(C_ADD, SEQ_FETCH);   
        
        rom(to_integer(uADDR_MAB))  := to_ucode(C_MAB, SEQ_FETCH);   
        
        rom(to_integer(uADDR_LDB1)) := to_ucode(C_LDB1, SEQ_NEXT);   
        rom(to_integer(uADDR_LDB2)) := to_ucode(C_LDB2, SEQ_FETCH);  
        
        rom(to_integer(uADDR_STB1)) := to_ucode(C_STB1, SEQ_NEXT);  
        rom(to_integer(uADDR_STB2)) := to_ucode(C_STB2, SEQ_FETCH);  
        
        rom(to_integer(uADDR_MBA))  := to_ucode(C_MBA, SEQ_FETCH);  
        
        rom(to_integer(uADDR_JMP))  := to_ucode(C_JMP, SEQ_FETCH); 
        
        rom(to_integer(uADDR_CMP))  := to_ucode(C_CMP, SEQ_FETCH);  
        
        rom(to_integer(uADDR_SUB))  := to_ucode(C_SUB, SEQ_FETCH);   
        
        rom(to_integer(uADDR_HLT))  := to_ucode(C_HLT, SEQ_HLT);   
       
        
        return rom;
    end function;

    -- Buat ROM
    constant Control_Store : t_control_store := init_rom;

    -- ### 3. Sinyal Internal ###
    
    -- Micro-Program Counter (uPC)
    signal uPC     : t_uAddress := uADDR_FETCH1;
    signal Next_uPC : t_uAddress;
    
    -- Micro-Instruction Register (uIR)
    signal uIR : std_logic_vector(C_UCODE_WIDTH - 1 downto 0);
    
begin

    -- ### PROSES 1: uPC Register (State Register) ###
    uPC_REGISTER: process(CLK) is
    begin
        if enable = '1' and rising_edge(CLK) then
            if RST = '1' then
                uPC <= uADDR_FETCH1; -- Reset kembali ke Fetch (alamat 0)
            else
                uPC <= Next_uPC;
            end if;
        end if;
    end process uPC_REGISTER;

    -- ### PROSES 2: Pembacaan ROM (Moore) ###
    -- Baca micro-instruction dari ROM berdasarkan uPC saat ini
    uIR <= Control_Store(to_integer(uPC));

    -- ### PROSES 3: Sequencer Logic (Menentukan uPC Berikutnya) ###
    -- Ini adalah "otak" yang "bodoh" dari kode hipotetis Anda.
    SEQUENCER_LOGIC: process(uPC, uIR, opcode, carry_flag, zero_flag)
        variable seq_control : std_logic_vector(1 downto 0);
    begin
        -- Ekstrak 2 bit sequencing dari micro-instruction saat ini
        seq_control := uIR(C_UCODE_WIDTH - 1 downto C_CTRL_BITS);
        
        -- Default: selalu increment (untuk jaga-jaga)
        Next_uPC <= uPC + 1;

        case seq_control is
            when SEQ_NEXT =>
                -- Perintah: Ambil micro-instruction berikutnya secara berurutan
                Next_uPC <= uPC + 1;
                
            when SEQ_FETCH =>
                -- Perintah: Kembali ke awal siklus Fetch
                Next_uPC <= uADDR_FETCH1;

            when SEQ_HLT =>
                -- Perintah: Berhenti! Tetap di alamat ini selamanya.
                Next_uPC <= uPC; 

            when SEQ_DECODE =>
                -- =============TODO: Implementasikan decoding opcode ke alamat micro-routine=============
                -- Perintah: Lihat opcode dan lompat ke alamat micro-routine yang sesuai
                -- Yaudah, mirip lah yak dengan state machine di modul sebelumnya.
                -- =======================================================================================

                
                case opcode is
                    when "0000" => Next_uPC <= uADDR_NOP1;
                    when "0001" => Next_uPC <= uADDR_LDA1;
                    when "0010" => Next_uPC <= uADDR_STA1;
                    when "0011" => Next_uPC <= uADDR_ADD;
                    when "0100" => Next_uPC <= uADDR_MAB;
                    when "0101" => Next_uPC <= uADDR_LDB1;
                    when "0110" => Next_uPC <= uADDR_STB1;
                    when "0111" => Next_uPC <= uADDR_MBA;
                    when "1000" => Next_uPC <= uADDR_JMP;
                    when "1001" => Next_uPC <= uADDR_CMP;
                    when "1010" =>  if zero_flag = '1' then Next_uPC <= uADDR_JMP; else Next_uPC <= uADDR_FETCH1; end if;
                    when "1011" =>  if zero_flag = '0' then Next_uPC <= uADDR_JMP; else Next_uPC <= uADDR_FETCH1; end if;
                    when "1110" =>  if carry_flag = '0' then Next_uPC <= uADDR_JMP; else Next_uPC <= uADDR_FETCH1; end if;
                    when "1101" =>  if carry_flag = '1' then Next_uPC <= uADDR_JMP; else Next_uPC <= uADDR_FETCH1; end if;
                    when "1100" => Next_uPC <= uADDR_SUB;
                    when "1111" => Next_uPC <= uADDR_HLT;
                   
                    when others => Next_uPC <= uADDR_FETCH1; 
                end case;
            when others =>
                -- Pengaman jika terjadi error
                Next_uPC <= uADDR_FETCH1;
        end case;
    end process SEQUENCER_LOGIC;

    -- ### PROSES 4: Output Logic ###
    -- Output-nya hanyalah 14 bit sinyal kontrol dari micro-instruction
    control_signals <= uIR(13 downto 0);

end architecture rtl_classic_microprogram;


