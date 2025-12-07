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
        
        -- ///// INTERFACE CONTROL UNIT /////
        control_signals     : in  std_logic_vector(4 downto 0);
        flag_dash_thresh    : out std_logic;
        flag_char_end       : out std_logic;
        flag_space_end      : out std_logic;
        flag_buff_has_data  : out std_logic;

        ascii_out   : out std_logic_vector(7 downto 0);
        valid_out   : out std_logic
    );
end entity morse_decoder;

architecture rtl of morse_decoder is

    -- ///// THRESHOLD /////
    
    
    -- Jika pulse < THRESHOLD_DASH, maka DOT.
    -- Kalau tidak DASH.
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

    -- ///// COMMAND CONSTANTS (From Control Unit) /////
    constant CMD_CLR_ALL        : std_logic_vector(4 downto 0) := "00001";
    constant CMD_INC_ONE        : std_logic_vector(4 downto 0) := "00010";
    constant CMD_INC_ZERO       : std_logic_vector(4 downto 0) := "00011";
    constant CMD_CLR_CNTS       : std_logic_vector(4 downto 0) := "00100";
    constant CMD_SHIFT_DOT      : std_logic_vector(4 downto 0) := "00101";
    constant CMD_SHIFT_DASH     : std_logic_vector(4 downto 0) := "00110";
    constant CMD_SHIFT_SEP      : std_logic_vector(4 downto 0) := "00111";
    constant CMD_DECODE_CHAR    : std_logic_vector(4 downto 0) := "01000";
    constant CMD_DECODE_SPACE   : std_logic_vector(4 downto 0) := "01001";

    signal counter_zero      : integer := 0;
    signal counter_one       : integer := 0;
    
    -- Max morse code untuk ASCII : 10.
    -- Shift Register untuk Input Buffer
    signal shiftreg_inb     : unsigned(9 downto 0);

begin

    -- ///// STATUS FLAGS /////
    flag_dash_thresh   <= '1' when counter_one >= THRESH_DASH else '0';
    flag_char_end      <= '1' when counter_zero >= THRESH_CHAR_END - 1 else '0';
    flag_space_end     <= '1' when counter_zero >= THRESH_SPACE - 1 else '0';
    flag_buff_has_data <= '1' when shiftreg_inb /= 0 else '0';

    process(clk, reset)
    begin
        if reset = '1' then
            counter_zero  <= 0;
            counter_one   <= 0;
            shiftreg_inb  <= "0000000000";
            ascii_out     <= (others => '0');
            valid_out     <= '0';
        elsif rising_edge(clk) then
            
            -- Default pulse output
            valid_out <= '0';

            case control_signals is
                
                -- State: Menunggu input (IDLE replacement)
                when CMD_CLR_ALL =>
                    counter_zero <= 0;
                    counter_one  <= 0;
                    shiftreg_inb <= (others => '0');

                -- State: Signal High (Mengukur 1)
                when CMD_INC_ONE =>
                    counter_one <= counter_one + 1;

                -- State: Signal Low (Mengukur 0)
                when CMD_INC_ZERO =>
                    counter_zero <= counter_zero + 1;
                
                when CMD_CLR_CNTS =>
                    counter_zero <= 0;
                    counter_one  <= 0;

                -- Analisis durasi '1' nya.
                when CMD_SHIFT_DOT =>
                    -- Input merupakan DOT ('1')
                    shiftreg_inb <= shiftreg_inb(8 downto 0) & '1';
                    counter_one <= 0;

                when CMD_SHIFT_DASH =>
                    -- Input merupakan DASH ('1')
                    shiftreg_inb <= shiftreg_inb(7 downto 0) & "11";
                    counter_one <= 0;

                -- Signal High lagi (Detected Rise)
                when CMD_SHIFT_SEP =>
                    -- sisipkan '0' untuk memisahkan simbol dot/dash
                    shiftreg_inb <= shiftreg_inb(8 downto 0) & '0';
                    counter_zero <= 0; 
                    -- Reset counter_one ke 0 untuk memulai pengukuran baru
                    counter_one <= 0; 

                -- State : Decode Letter
                when CMD_DECODE_CHAR =>
                    valid_out <= '1';
                    case to_integer(shiftreg_inb) is
                        -- 1 simbol
                        when 1       => ascii_out <= x"45"; -- E (.) = 1
                        when 3       => ascii_out <= x"54"; -- T (-) = 11
                    
                        -- 2 simbol
                        when 5       => ascii_out <= x"49"; -- I (..) = 101
                        when 11      => ascii_out <= x"41"; -- A (.-) = 1011
                        when 13      => ascii_out <= x"4E"; -- N (-.) = 1101
                        when 27      => ascii_out <= x"4D"; -- M (--) = 11011
                        
                        -- 3 simbol
                        when 21      => ascii_out <= x"53"; -- S (...) = 10101
                        when 43      => ascii_out <= x"55"; -- U (..-) = 101011
                        when 45      => ascii_out <= x"52"; -- R (.-.) = 101101
                        when 91      => ascii_out <= x"57"; -- W (.--) = 1011011
                        when 53      => ascii_out <= x"44"; -- D (-..) = 110101
                        when 107     => ascii_out <= x"4B"; -- K (-.-) = 1101011
                        when 109     => ascii_out <= x"47"; -- G (--.) = 1101101
                        when 219     => ascii_out <= x"4F"; -- O (---) = 11011011
                    
                        -- 4 simbol
                        when 85      => ascii_out <= x"48"; -- H (....) = 1010101
                        when 171     => ascii_out <= x"56"; -- V (...-) = 10101011
                        when 173     => ascii_out <= x"46"; -- F (..-.) = 10101101
                        when 181     => ascii_out <= x"4C"; -- L (.-..) = 10110101
                        when 365     => ascii_out <= x"50"; -- P (.--.) = 101101101
                        when 437     => ascii_out <= x"5A"; -- Z (--..) = 110110101
                        when 731     => ascii_out <= x"4A"; -- J (.---) = 1011011011
                        when 213     => ascii_out <= x"42"; -- B (-...) = 11010101
                        when 427     => ascii_out <= x"58"; -- X (-..-) = 110101011
                        when 429     => ascii_out <= x"43"; -- C (-.-.) = 110101101
                        when 859     => ascii_out <= x"59"; -- Y (-.--) = 1101011011
                        when 875     => ascii_out <= x"51"; -- Q (--.-) = 1101101011
                        
                        -- kalo morse tidak dikenal 
                        when others  => ascii_out <= x"3F"; -- ? 
                    end case;
                    
                    -- Reset untuk letter selanjutnya
                    shiftreg_inb <= "0000000000";

                -- State: NEXT WORD / DECODE_SPACE
                when CMD_DECODE_SPACE =>
                    ascii_out <= x"20";
                    -- ASCII space
                    valid_out <= '1';
                    counter_zero   <= 0;
                    counter_one <= 0;
                    -- __________ LOGIKA SPACE ________

                when others =>
                    null;
            end case;
        end if;
    end process;

    -- Write the output to .txt file
    TXT_OUTPUT: process(clk)
        file output_file        : text open write_mode is "output.txt";
        variable current_line   : line;
        variable char_count     : integer := 0;
        variable word_count     : integer := 0; 
        variable ascii_int      : integer;
        variable char           : character;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Check if we have written anything to the current line.
                -- If we have, save it before resetting the counters.
                if word_count > 0 or char_count > 0 then
                    writeline(output_file, current_line);
                end if;

                char_count := 0;
                word_count := 0;

            elsif valid_out = '1' then
                
                ascii_int := to_integer(unsigned(ascii_out));
                char := character'val(ascii_int);
                
                -- Logic for SPACE
                if char = ' ' then
                    write(current_line, char);
                    word_count := word_count + 1;
                    char_count := 0; 
                    
                    -- Check Sentence Limit (16 Words)
                    if word_count >= 16 then
                        writeline(output_file, current_line);
                        word_count := 0; 
                    end if;
                    
                -- Logic for LETTERS
                else
                    -- Check Word Limit (32 Letters)
                    if char_count < 32 then
                        write(current_line, char);
                        char_count := char_count + 1;
                    else
                        -- Ignore extra letters > 32
                        null;
                    end if;
                end if;
            end if;
        end if;
    end process TXT_OUTPUT;
            
end architecture;
