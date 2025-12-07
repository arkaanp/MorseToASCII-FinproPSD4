library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity morse_decoder is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        morse_in    : in  std_logic;
        ascii_out   : out std_logic_vector(7 downto 0);
        valid_out   : out std_logic
    );
end entity morse_decoder;

architecture rtl of morse_decoder is

    -- Component Declaration for Control Unit
    component control_unit
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            morse_in        : in  std_logic;
            flag_char_end   : in  std_logic;
            flag_space_end  : in  std_logic;
            ctrl_clr_all    : out std_logic;
            ctrl_inc_one    : out std_logic;
            ctrl_inc_zero   : out std_logic;
            ctrl_proc_pulse : out std_logic;
            ctrl_proc_gap   : out std_logic;
            ctrl_dec_char   : out std_logic;
            ctrl_dec_space  : out std_logic
        );
    end component;

    -- ///// THRESHOLD /////
    
    -- Jika pulse < THRESHOLD_DASH, maka DOT. Kalau tidak DASH.
    -- Sesuai dengan standar morse, '1' adalah dot. Jadi, jika counter_one = 2, akan dideteksi sebagai '1'.
    constant THRESH_DASH     : integer := 2;

    -- Jika gap ('0') > THRESH_CHAR_END, satu huruf telah selesai.
    -- Sesuai dengan standar morse, tiga '0' adalah gap untuk pemisah character
    constant THRESH_CHAR_END : integer := 3;

    -- Jika gap > THRESH_SPACE, akan ada spasi.
    -- Sesuai dengan standar morse, tujuh '0' adalah gap untuk pemisah kalimat.
    constant THRESH_SPACE    : integer := 7;

    -- INB : Jumlah maksimum bit di Input Buffer
    constant THRESH_INB      : integer := 10;

    -- Registers
    signal counter_zero   : integer := 0;
    signal counter_one    : integer := 0;
    
    -- Max morse code untuk ASCII : 10.
    -- Shift Register untuk Input Buffer
    signal shiftreg_inb   : unsigned(9 downto 0);
    signal counter_signal : integer := 0;
    
    -- Internal outputs
    signal ascii_out_int : std_logic_vector(7 downto 0);
    signal valid_out_int : std_logic;

    -- Flags to send to CU
    signal flag_char_end  : std_logic;
    signal flag_space_end : std_logic;

    -- Control Signals from CU
    signal ctrl_clr_all    : std_logic;
    signal ctrl_inc_one    : std_logic;
    signal ctrl_inc_zero   : std_logic;
    signal ctrl_proc_pulse : std_logic;
    signal ctrl_proc_gap   : std_logic;
    signal ctrl_dec_char   : std_logic;
    signal ctrl_dec_space  : std_logic;

    -- FLAGS
    signal NL : std_logic := '0'; -- Next Letter
    signal NW : std_logic := '0'; -- Next Word, indikasi kalimat

begin

    -- Instantiate the Brain (Control Unit)
    CU_INST : control_unit
    port map (
        clk             => clk,
        reset           => reset,
        morse_in        => morse_in,
        flag_char_end   => flag_char_end,
        flag_space_end  => flag_space_end,
        ctrl_clr_all    => ctrl_clr_all,
        ctrl_inc_one    => ctrl_inc_one,
        ctrl_inc_zero   => ctrl_inc_zero,
        ctrl_proc_pulse => ctrl_proc_pulse,
        ctrl_proc_gap   => ctrl_proc_gap,
        ctrl_dec_char   => ctrl_dec_char,
        ctrl_dec_space  => ctrl_dec_space
    );

    -- Generate Flags (Combinational Logic)
    -- We check for "Threshold - 1" to match the timing of the original code
    flag_char_end  <= '1' when (counter_zero = THRESH_CHAR_END - 1) else '0';
    flag_space_end <= '1' when (counter_zero = THRESH_SPACE - 1) else '0';

    -- Main Datapath Process
    process(clk, reset)
    begin
        if reset = '1' then
            counter_zero   <= 0;
            counter_one    <= 0;
            shiftreg_inb   <= (others => '0');
            ascii_out_int  <= (others => '0');
            valid_out_int  <= '0';
            counter_signal <= 0;
            NL <= '0';
            NW <= '0';

        elsif rising_edge(clk) then
            -- Default
            valid_out_int <= '0';

            -- 1. Clear All (IDLE)
            if ctrl_clr_all = '1' then
                counter_zero <= 0;
                counter_one  <= 0;
            end if;

            -- 2. Increment High Counter
            if ctrl_inc_one = '1' then
                counter_one <= counter_one + 1;
            end if;

            -- 3. Process Pulse (Transition High -> Low)
            -- Logic: Signal jadi low. Analisis durasi '1' nya.
            if ctrl_proc_pulse = '1' then
                if counter_one < THRESH_DASH then
                    -- Input merupakan DOT ('1')
                    counter_signal <= counter_signal + 1;
                    shiftreg_inb   <= shiftreg_inb(8 downto 0) & '1';
                else
                    -- Input merupakan DASH ('1')
                    counter_signal <= counter_signal + 2;
                    shiftreg_inb   <= shiftreg_inb(7 downto 0) & "11";
                end if;
                counter_one  <= 0;
                counter_zero <= counter_zero + 1; -- Start counting gap
            end if;

            -- 4. Increment Low Counter & Check internal logic
            if ctrl_inc_zero = '1' then
                if counter_zero < THRESH_SPACE then
                    counter_zero <= counter_zero + 1;
                end if;
                
                -- Cek letter timeout (Logic padding bit '0')
                if flag_char_end = '1' then
                     if counter_signal = 9 then shiftreg_inb <= shiftreg_inb(8 downto 0) & '0';
                     elsif counter_signal = 8 then shiftreg_inb <= shiftreg_inb(7 downto 0) & "00";
                     elsif counter_signal = 7 then shiftreg_inb <= shiftreg_inb(6 downto 0) & "000";
                     elsif counter_signal = 6 then shiftreg_inb <= shiftreg_inb(5 downto 0) & "0000";
                     elsif counter_signal = 5 then shiftreg_inb <= shiftreg_inb(4 downto 0) & "00000";
                     elsif counter_signal = 4 then shiftreg_inb <= shiftreg_inb(3 downto 0) & "000000";
                     elsif counter_signal = 3 then shiftreg_inb <= shiftreg_inb(2 downto 0) & "0000000";
                     elsif counter_signal = 2 then shiftreg_inb <= shiftreg_inb(1 downto 0) & "00000000";
                     elsif counter_signal = 1 then shiftreg_inb <= shiftreg_inb(0) & "000000000";
                     end if;
                     
                     counter_signal <= 0;
                     NL <= '1'; -- Next Letter Flag
                end if;

                -- Cek word
                if flag_space_end = '1' then
                    NW <= '1'; -- Next Word Flag
                end if;
            end if;

            -- 5. Process Gap Rise (Transition Low -> High)
            -- Logic: Signal High lagi
            if ctrl_proc_gap = '1' then
                -- sisipkan '0' untuk memisahkan simbol dot/dash
                if NL = '0' then
                    counter_signal <= counter_signal + 1;
                else
                    NL <= '0';
                end if;
                shiftreg_inb <= shiftreg_inb(8 downto 0) & '0';
                counter_one <= 1; -- Start counting the new pulse
                counter_zero <= 0;
            end if;

            -- 6. Decode Character
            if ctrl_dec_char = '1' then
                valid_out_int <= '1';
                case to_integer(shiftreg_inb) is
                    -- 1 simbol
                    when 512 => ascii_out_int <= x"45"; -- E (.) = 1
                    when 768 => ascii_out_int <= x"54"; -- T (-) = 11
                    -- 2 simbol
                    when 640 => ascii_out_int <= x"49"; -- I (..) = 101
                    when 704 => ascii_out_int <= x"41"; -- A (.-) = 1011
                    when 832 => ascii_out_int <= x"4E"; -- N (-.) = 1101
                    when 864 => ascii_out_int <= x"4D"; -- M (--) = 11011
                    -- 3 simbol
                    when 672 => ascii_out_int <= x"53"; -- S (...) = 10101
                    when 688 => ascii_out_int <= x"55"; -- U (..-) = 101011
                    when 720 => ascii_out_int <= x"52"; -- R (.-.) = 101101
                    when 728 => ascii_out_int <= x"57"; -- W (.--) = 1011011
                    when 848 => ascii_out_int <= x"44"; -- D (-..) = 110101
                    when 856 => ascii_out_int <= x"4B"; -- K (-.-) = 1101011
                    when 872 => ascii_out_int <= x"47"; -- G (--.) = 1101101
                    when 876 => ascii_out_int <= x"4F"; -- O (---) = 11011011
                    -- 4 simbol
                    when 680 => ascii_out_int <= x"48"; -- H (....) = 1010101
                    when 684 => ascii_out_int <= x"56"; -- V (...-) = 10101011
                    when 692 => ascii_out_int <= x"46"; -- F (..-.) = 10101101
                    when 724 => ascii_out_int <= x"4C"; -- L (.-..) = 10110101
                    when 730 => ascii_out_int <= x"50"; -- P (.--.) = 101101101
                    when 874 => ascii_out_int <= x"5A"; -- Z (--..) = 110110101
                    when 731 => ascii_out_int <= x"4A"; -- J (.---) = 1011011011
                    when 852 => ascii_out_int <= x"42"; -- B (-...) = 11010101
                    when 854 => ascii_out_int <= x"58"; -- X (-..-) = 110101011
                    when 858 => ascii_out_int <= x"43"; -- C (-.-.) = 110101101
                    when 859 => ascii_out_int <= x"59"; -- Y (-.--) = 1101011011
                    when 875 => ascii_out_int <= x"51"; -- Q (--.-) = 1101101011
                    -- kalo morse tidak dikenal 
                    when others => ascii_out_int <= x"3F"; -- ? 
                end case;
                
                -- Reset untuk letter selanjutnya
                shiftreg_inb <= (others => '0');
            end if;

            -- 7. Decode Space
            if ctrl_dec_space = '1' then
                ascii_out_int <= x"20"; -- ASCII space
                valid_out_int <= '1';
                counter_zero  <= 0;
                counter_one   <= 0;
                NW <= '0';
                NL <= '0';
            end if;

        end if;
    end process;

    -- Connect Internal Signals to Output Ports
    ascii_out <= ascii_out_int;
    valid_out <= valid_out_int;

    -- TXT_OUTPUT (UNCHANGED)
    TXT_OUTPUT: process(clk)
        file output_file         : text open write_mode is "output.txt";
        variable current_line    : line;
        variable char_count      : integer := 0; 
        variable word_count      : integer := 0; 
        variable ascii_int       : integer;
        variable char            : character;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                if word_count > 0 or char_count > 0 then
                    writeline(output_file, current_line);
                end if;
                char_count := 0;
                word_count := 0;
            elsif valid_out_int = '1' then
                ascii_int := to_integer(unsigned(ascii_out_int));
                char := character'val(ascii_int);
                if char = ' ' then
                    write(current_line, char); 
                    word_count := word_count + 1;
                    char_count := 0; 
                    if word_count >= 16 then
                        writeline(output_file, current_line); 
                        word_count := 0; 
                    end if;
                else
                    if char_count < 32 then
                        write(current_line, char);
                        char_count := char_count + 1;
                    else
                        null; 
                    end if;
                end if;
            end if;
        end if;
    end process TXT_OUTPUT;

end architecture;
