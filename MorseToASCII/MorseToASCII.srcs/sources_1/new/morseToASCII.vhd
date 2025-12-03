library ieee;
use ieee.std_logic_1164.all;

entity morseToASCII is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        morse_in  : in  std_logic;
        ascii_out : out std_logic_vector(7 downto 0);
        valid_out : out std_logic
    );
end entity morseToASCII;

architecture struct of morseToASCII is

    signal control_sigs_5bit : std_logic_vector(4 downto 0);
    signal opcode_4bit       : std_logic_vector(3 downto 0);
    
    signal flag_dash   : std_logic;
    signal flag_char   : std_logic;
    signal flag_space  : std_logic;
    signal flag_buff   : std_logic;

begin

    U_CONTROL : entity work.control_unit
    port map (
        clk                => clk,
        reset              => reset,
        morse_in           => morse_in,
        flag_dash_thresh   => flag_dash,
        flag_char_end      => flag_char,
        flag_space_end     => flag_space,
        flag_buff_has_data => flag_buff,
        control_signals    => control_sigs_5bit
    );

    opcode_4bit <= control_sigs_5bit(3 downto 0);

    U_DATAPATH : entity work.morse_decoder
    port map (
        clk              => clk,
        reset            => reset,
        opcode_in        => opcode_4bit,
        flag_dash_thresh => flag_dash,
        flag_char_end    => flag_char,
        flag_space_end   => flag_space,
        flag_buff_has_data => flag_buff,
        ascii_out        => ascii_out,
        valid_out        => valid_out
    );

end architecture;