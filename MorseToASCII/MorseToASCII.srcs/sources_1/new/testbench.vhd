library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_morse_specific is
end entity tb_morse_specific;

architecture behavior of tb_morse_specific is

    component morse_decoder
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        morse_in    : in  std_logic; 
        
        ascii_out   : out std_logic_vector(7 downto 0);
        valid_out   : out std_logic
    );
    end component;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '0';
    signal morse_in : std_logic := '0';
    signal ascii_out : std_logic_vector(7 downto 0);
    signal valid_out : std_logic;

    constant CLK_PERIOD : time := 20 ns;

    signal char_debug : character := ' ';
   

begin

    uut: morse_decoder port map (
        clk       => clk,
        reset     => reset,
        morse_in  => morse_in,
        ascii_out => ascii_out,
        valid_out => valid_out
    );

    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if valid_out = '1' then
                char_debug <= character'val(to_integer(unsigned(ascii_out)));
            end if;
        end if;
    end process;

    -- Main Stimulus Process
    stim_proc: process


        procedure send_dot is
        begin
            morse_in <= '1';
            wait for CLK_PERIOD * 1; 
            morse_in <= '0';
            wait for CLK_PERIOD * 2;
        end procedure;

        procedure send_dash is
        begin
            morse_in <= '1';
            wait for CLK_PERIOD * 4; 
            morse_in <= '0';
            wait for CLK_PERIOD * 2;
        end procedure;

        procedure end_char is
        begin
             wait for CLK_PERIOD * 3; 
        end procedure;

        procedure send_space is
        begin
            wait for CLK_PERIOD * 8;
        end procedure;

        procedure send_character(c : character) is
        begin
            case c is
                when 'l' => send_dot; send_dash; send_dot; send_dot; end_char;
                when 'i' => send_dot; send_dot; end_char;
                when 's' => send_dot; send_dot; send_dot; end_char;
                when 't' => send_dash; end_char;
                when 'o' => send_dash; send_dash; send_dash; end_char;
                when 'f' => send_dot; send_dot; send_dash; send_dot; end_char;
                when 'h' => send_dot; send_dot; send_dot; send_dot; end_char;
                when 'e' => send_dot; end_char;
                when 'n' => send_dash; send_dot; end_char;
                when 'g' => send_dash; send_dash; send_dot; end_char;
                when 'a' => send_dot; send_dash; end_char;
                when 'm' => send_dash; send_dash; end_char;
                when ' ' => send_space;
                when others => report "Skipping unknown char" severity note;
            end case;
        end procedure;

        -- Kalimat
        constant my_string : string := "list of the things that i hate the most";

    begin
        reset <= '1';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        wait for CLK_PERIOD * 5;

        report "Generating Morse for: " & my_string;

        -- mengirim morse sequence
        for i in my_string'range loop
            send_character(my_string(i));
        end loop;

        wait for CLK_PERIOD * 50;

        report "Simulation Finished. Flushing buffer to output.txt...";
        reset <= '1';
        wait for CLK_PERIOD * 5;
        reset <= '0';
        
        wait for CLK_PERIOD * 10;
        assert false report "End of Simulation (Success)" severity failure;

    end process;

end architecture;