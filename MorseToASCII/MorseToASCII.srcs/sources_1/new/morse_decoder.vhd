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

    -- ///// THRESHOLD UPDATED /////
    
    -- UPDATE: Dinaikkan ke 3. 
    -- Dot (stimulus 1 cycle) akan terbaca 1-2 count -> dianggap Dot (<3).
    -- Dash (stimulus 4 cycle) akan terbaca 4-5 count -> dianggap Dash (>=3).
    constant THRESH_DASH     : integer := 3; 
    
    -- UPDATE: Diturunkan ke 2.
    -- Overhead Control Unit memakan ~3 cycle.
    -- Gap antar huruf (5 cycle) dikurangi overhead = sisa 2 cycle terukur.
    -- Jadi ambang batas harus 2 agar End-of-Char terdeteksi.
    constant THRESH_CHAR_END : integer := 2;
    
    -- Gap spasi (8 cycle) cukup panjang sehingga aman.
    constant THRESH_SPACE    : integer := 7; 
    
    constant THRESH_INB      : integer := 10;

    -- ///// COMMAND CONSTANTS /////
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
    signal shiftreg_inb      : unsigned(9 downto 0);

begin

    -- ///// STATUS FLAGS /////
    flag_dash_thresh   <= '1' when counter_one >= THRESH_DASH else '0';
    -- Flag char end trigger jika counter_zero >= 1 (karena THRESH_CHAR_END - 1)
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
            
            valid_out <= '0';

            case control_signals is
                
                when CMD_CLR_ALL =>
                    counter_zero <= 0;
                    counter_one  <= 0;
                    shiftreg_inb <= (others => '0');

                when CMD_INC_ONE =>
                    counter_one <= counter_one + 1;

                when CMD_INC_ZERO =>
                    counter_zero <= counter_zero + 1;
                
                when CMD_CLR_CNTS =>
                    counter_zero <= 0;
                    counter_one  <= 0;

                when CMD_SHIFT_DOT =>
                    shiftreg_inb <= shiftreg_inb(8 downto 0) & '1';
                    counter_one <= 0;

                when CMD_SHIFT_DASH =>
                    shiftreg_inb <= shiftreg_inb(7 downto 0) & "11";
                    counter_one <= 0;

                when CMD_SHIFT_SEP =>
                    shiftreg_inb <= shiftreg_inb(8 downto 0) & '0';
                    counter_zero <= 0; 
                    counter_one <= 0; 

                when CMD_DECODE_CHAR =>
                    valid_out <= '1';
                    case to_integer(shiftreg_inb) is
                        -- 1 simbol
                        when 1       => ascii_out <= x"45"; -- E
                        when 3       => ascii_out <= x"54"; -- T
                        -- 2 simbol
                        when 5       => ascii_out <= x"49"; -- I
                        when 11      => ascii_out <= x"41"; -- A
                        when 13      => ascii_out <= x"4E"; -- N
                        when 27      => ascii_out <= x"4D"; -- M
                        -- 3 simbol
                        when 21      => ascii_out <= x"53"; -- S
                        when 43      => ascii_out <= x"55"; -- U
                        when 45      => ascii_out <= x"52"; -- R
                        when 91      => ascii_out <= x"57"; -- W
                        when 53      => ascii_out <= x"44"; -- D
                        when 107     => ascii_out <= x"4B"; -- K
                        when 109     => ascii_out <= x"47"; -- G
                        when 219     => ascii_out <= x"4F"; -- O
                        -- 4 simbol
                        when 85      => ascii_out <= x"48"; -- H
                        when 171     => ascii_out <= x"56"; -- V
                        when 173     => ascii_out <= x"46"; -- F
                        when 181     => ascii_out <= x"4C"; -- L
                        when 365     => ascii_out <= x"50"; -- P
                        when 437     => ascii_out <= x"5A"; -- Z
                        when 731     => ascii_out <= x"4A"; -- J
                        when 213     => ascii_out <= x"42"; -- B
                        when 427     => ascii_out <= x"58"; -- X
                        when 429     => ascii_out <= x"43"; -- C
                        when 859     => ascii_out <= x"59"; -- Y
                        when 875     => ascii_out <= x"51"; -- Q
                        when others  => ascii_out <= x"3F"; -- ? 
                    end case;
                    shiftreg_inb <= "0000000000";

                when CMD_DECODE_SPACE =>
                    ascii_out <= x"20"; -- Space
                    valid_out <= '1';
                    counter_zero <= 0;
                    counter_one <= 0;

                when others =>
                    null;
            end case;
        end if;
    end process;

    -- TXT_OUTPUT Process tetap sama seperti sebelumnya
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
                if word_count > 0 or char_count > 0 then
                    writeline(output_file, current_line);
                end if;
                char_count := 0;
                word_count := 0;
            elsif valid_out = '1' then
                ascii_int := to_integer(unsigned(ascii_out));
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
