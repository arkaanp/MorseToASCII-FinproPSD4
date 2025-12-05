library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity morse_decoder is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        opcode_in   : in  std_logic_vector(3 downto 0);
        flag_dash_thresh : out std_logic;
        flag_char_end    : out std_logic;
        flag_space_end   : out std_logic;
        flag_buff_has_data: out std_logic;
        ascii_out   : out std_logic_vector(7 downto 0);
        valid_out   : out std_logic
    );
end entity morse_decoder;

architecture rtl of morse_decoder is
    constant THRESH_DASH     : integer := 2;
    constant THRESH_CHAR_END : integer := 3;
    constant THRESH_SPACE    : integer := 7;

    constant OP_NOP          : std_logic_vector(3 downto 0) := "0000";
    constant OP_CLR_ALL      : std_logic_vector(3 downto 0) := "0001";
    constant OP_INC_ONE      : std_logic_vector(3 downto 0) := "0010";
    constant OP_INC_ZERO     : std_logic_vector(3 downto 0) := "0011";
    constant OP_CLR_CNTS     : std_logic_vector(3 downto 0) := "0100";
    constant OP_SHIFT_DOT    : std_logic_vector(3 downto 0) := "0101";
    constant OP_SHIFT_DASH   : std_logic_vector(3 downto 0) := "0110";
    constant OP_SHIFT_SEP    : std_logic_vector(3 downto 0) := "0111";
    constant OP_DECODE_CHAR  : std_logic_vector(3 downto 0) := "1000";
    constant OP_DECODE_SPACE : std_logic_vector(3 downto 0) := "1001";

    signal counter_zero : integer range 0 to 100 := 0;
    signal counter_one  : integer range 0 to 100 := 0;
    signal shiftreg_inb : unsigned(9 downto 0) := (others => '0');
   
begin


    flag_dash_thresh   <= '1' when counter_one >= THRESH_DASH else '0';
    flag_char_end      <= '1' when counter_zero = THRESH_CHAR_END else '0';
    flag_space_end     <= '1' when counter_zero = THRESH_SPACE else '0';

    flag_buff_has_data <= '1' when shiftreg_inb > 0 else '0';


    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter_zero <= 0;
                counter_one  <= 0;
                shiftreg_inb <= (others => '0');
                ascii_out    <= (others => '0');
                valid_out    <= '0';
            else
                valid_out <= '0';
               
                case opcode_in is
                    when OP_NOP =>
                        null;
                    when OP_CLR_ALL =>
                        counter_zero <= 0;
                        counter_one  <= 0;
                        shiftreg_inb <= (others => '0');
                    when OP_CLR_CNTS =>
                        counter_zero <= 0;
                        counter_one  <= 0;
                    when OP_INC_ONE =>
                        counter_one <= counter_one + 1;
                    when OP_INC_ZERO =>
                        counter_zero <= counter_zero + 1;
                    when OP_SHIFT_DOT =>
                        shiftreg_inb <= shiftreg_inb(8 downto 0) & '1';
                        counter_one <= 0;
                    when OP_SHIFT_DASH =>
                        shiftreg_inb <= shiftreg_inb(7 downto 0) & "11";
                        counter_one <= 0;
                    when OP_SHIFT_SEP =>
                        shiftreg_inb <= shiftreg_inb(8 downto 0) & '0';
                        counter_zero <= 0;
                        counter_one  <= 0;
                    when OP_DECODE_SPACE =>
                        ascii_out <= x"20";
                        valid_out <= '1';
                        counter_zero <= 0;
                       
                    when OP_DECODE_CHAR =>
                        valid_out <= '1';
                        case to_integer(shiftreg_inb) is
                            when 1      => ascii_out <= x"45";
                            when 3      => ascii_out <= x"54";
                            when 5      => ascii_out <= x"49";
                            when 11     => ascii_out <= x"41";
                            when 13     => ascii_out <= x"4E";
                            when 27     => ascii_out <= x"4D";
                            when 21     => ascii_out <= x"53";
                            when 43     => ascii_out <= x"55";
                            when 45     => ascii_out <= x"52";
                            when 91     => ascii_out <= x"57";
                            when 53     => ascii_out <= x"44";
                            when 107    => ascii_out <= x"4B";
                            when 109    => ascii_out <= x"47";
                            when 219    => ascii_out <= x"4F";
                            when 85     => ascii_out <= x"48";
                            when 171    => ascii_out <= x"56";
                            when 173    => ascii_out <= x"46";
                            when 181    => ascii_out <= x"4C";
                            when 365    => ascii_out <= x"50";
                            when 437    => ascii_out <= x"5A";
                            when 731    => ascii_out <= x"4A";
                            when 213    => ascii_out <= x"42";
                            when 427    => ascii_out <= x"58";
                            when 429    => ascii_out <= x"43";
                            when 859    => ascii_out <= x"59";
                            when 875    => ascii_out <= x"51";
                            when others => ascii_out <= x"3F";
                        end case;
                        shiftreg_inb <= (others => '0');
                       
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;


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