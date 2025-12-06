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
    
    -- FSM
    type state_type is (IDLE, SIGNAL_HIGH, SIGNAL_LOW, DECODE_CHAR, DECODE_SPACE);
    
    signal current_state : state_type := IDLE;

    signal counter_zero      : integer := 0;
    signal counter_one       : integer := 0;
    
    -- Max morse code untuk ASCII : 10.
    -- Shift Register untuk Input Buffer
    signal shiftreg_inb     : unsigned(9 downto 0);
    
    -- FLAG
    
    signal NW : std_logic := '0'; --Next Word, indikasi kalimat
    signal NL : std_logic := '0'; --Next Letter
    signal FL : std_logic := '0'; -- FULL, indikasi kalau shiftreg_inb udah full
    
    signal counter_signal : integer := 0;

begin

    process(clk, reset)

    begin
        if reset = '1' then
            current_state <= IDLE;
            counter_zero  <= 0;
            counter_one   <= 0;
            shiftreg_inb  <= "0000000000"; 
            ascii_out     <= (others => '0');
            valid_out     <= '0';
            
        elsif rising_edge(clk) then
            
            -- Default pulse output
            valid_out <= '0';

            case current_state is
            
                -- State: Menunggu input
                when IDLE =>
                    counter_zero <= 0;
                    counter_one <= 0;
                    if morse_in = '1' then
                        counter_one <= counter_one + 1;
                        current_state <= SIGNAL_HIGH;
                    end if;

                -- State: Signal High (Mengukur 1)
                when SIGNAL_HIGH =>
                    if morse_in = '1' then
                            counter_one <= counter_one + 1;
                    else
                        -- Signal jadi low. Analisis durasi '1' nya.
                        if counter_one < THRESH_DASH then
                            -- Input merupakan DOT ('1')
                            counter_signal <= counter_signal + 1;
                            shiftreg_inb <= shiftreg_inb(8 downto 0) & '1';
                        else
                            -- Input merupakan DASH ('1')
                            counter_signal <= counter_signal + 2;
                            shiftreg_inb <= shiftreg_inb(7 downto 0) & "11";
                        end if;
                        
                        counter_one <= 0;
                        counter_zero <= counter_zero + 1;
                        current_state <= SIGNAL_LOW;
                    end if;

                -- State: Signal Low (Mengukur 0)
                when SIGNAL_LOW =>
                    if morse_in = '0' then
                        if counter_zero < THRESH_SPACE then
                            counter_zero <= counter_zero + 1;
                        end if;
                        
                        -- Cek letter timeout
                        if counter_zero = THRESH_CHAR_END - 1 then
                            if counter_signal = 9 then
                                shiftreg_inb <= shiftreg_inb(8 downto 0) & '0';
                            elsif counter_signal = 8 then
                                shiftreg_inb <= shiftreg_inb(7 downto 0) & "00";
                            elsif counter_signal = 7 then
                                shiftreg_inb <=  shiftreg_inb(6 downto 0) & "000";
                            elsif counter_signal = 6 then
                                shiftreg_inb <= shiftreg_inb(5 downto 0) & "0000";
                            elsif counter_signal = 5 then
                                shiftreg_inb <=  shiftreg_inb(4 downto 0) & "00000";
                            elsif counter_signal = 4 then
                                shiftreg_inb <= shiftreg_inb(3 downto 0) & "000000";
                            elsif counter_signal = 3 then
                                shiftreg_inb <=  shiftreg_inb(2 downto 0) & "0000000";
                            elsif counter_signal = 2 then
                                shiftreg_inb <= shiftreg_inb(1 downto 0) & "00000000";
                            elsif counter_signal = 1 then
                                shiftreg_inb <=  shiftreg_inb(0) & "000000000";
                            end if;
                            counter_signal <= 0;
                            current_state <= DECODE_CHAR;
                            NL <= '1';
                        -- Cek word
                        elsif counter_zero = THRESH_SPACE - 1 then
                            current_state <= DECODE_SPACE;
                            NW <= '1';
                        end if;
                    else
                        -- Signal High lagi
                        -- sisipkan '0' untuk memisahkan simbol dot/dash
                        if NL = '0' then
                            counter_signal <= counter_signal + 1;
                        else
                            NL <= '0';
                        end if;
                        shiftreg_inb <= shiftreg_inb(8 downto 0) & '0';
                        
                        counter_one <= 1;
                        counter_zero <= 0;
                        current_state <= SIGNAL_HIGH;
                    end if;

                -- State : Decode Letter
                when DECODE_CHAR =>
                    valid_out <= '1';
                   
                    
                   
                    case to_integer(shiftreg_inb) is
                        -- 1 simbol
                        when 512      => ascii_out <= x"45"; -- E (.) = 1
                        when 768      => ascii_out <= x"54"; -- T (-) = 11
                    
                        -- 2 simbol
                        when 640      => ascii_out <= x"49"; -- I (..) = 101
                        when 704     => ascii_out <= x"41"; -- A (.-) = 1011
                        when 832     => ascii_out <= x"4E"; -- N (-.) = 1101
                        when 864     => ascii_out <= x"4D"; -- M (--) = 11011
                        
                        -- 3 simbol
                        when 672     => ascii_out <= x"53"; -- S (...) = 10101
                        when 688     => ascii_out <= x"55"; -- U (..-) = 101011
                        when 720     => ascii_out <= x"52"; -- R (.-.) = 101101
                        when 728     => ascii_out <= x"57"; -- W (.--) = 1011011
                        when 848     => ascii_out <= x"44"; -- D (-..) = 110101
                        when 856    => ascii_out <= x"4B"; -- K (-.-) = 1101011
                        when 872    => ascii_out <= x"47"; -- G (--.) = 1101101
                        when 876    => ascii_out <= x"4F"; -- O (---) = 11011011
                    
                        -- 4 simbol
                        when 680     => ascii_out <= x"48"; -- H (....) = 1010101
                        when 684    => ascii_out <= x"56"; -- V (...-) = 10101011
                        when 692    => ascii_out <= x"46"; -- F (..-.) = 10101101
                        when 724    => ascii_out <= x"4C"; -- L (.-..) = 10110101
                        when 730    => ascii_out <= x"50"; -- P (.--.) = 101101101
                        when 874    => ascii_out <= x"5A"; -- Z (--..) = 110110101
                        when 731    => ascii_out <= x"4A"; -- J (.---) = 1011011011
                        when 852    => ascii_out <= x"42"; -- B (-...) = 11010101
                        when 854    => ascii_out <= x"58"; -- X (-..-) = 110101011
                        when 858    => ascii_out <= x"43"; -- C (-.-.) = 110101101
                        when 859    => ascii_out <= x"59"; -- Y (-.--) = 1101011011
                        when 875    => ascii_out <= x"51"; -- Q (--.-) = 1101101011
                        
                        -- kalo morse tidak dikenal 
                        when others => ascii_out <= x"3F"; -- ? 
                    end case;
                    
                    -- Reset untuk letter selanjutnya
                    shiftreg_inb <= "0000000000";
                    -- Kembali ke IDLE
                    current_state <= SIGNAL_LOW; 

                -- State: NEXT WORD
                when DECODE_SPACE =>
                    ascii_out <= x"20"; -- ASCII space
                    valid_out <= '1';
                    counter_zero   <= 0;
                    counter_one <= 0;
                    current_state <= IDLE;
                    -- __________ LOGIKA SPACE ________
                    NW <= '0';
                    NL <= '0';

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