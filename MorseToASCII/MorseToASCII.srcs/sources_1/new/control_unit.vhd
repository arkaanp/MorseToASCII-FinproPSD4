library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        morse_in    : in  std_logic;
        flag_dash_thresh   : in std_logic;
        flag_char_end      : in std_logic;
        flag_space_end     : in std_logic;
        flag_buff_has_data : in std_logic;
        control_signals  : out std_logic_vector(4 downto 0) 
    );
end entity control_unit;

architecture microprogrammed of control_unit is

    constant C_SEQ_BITS  : integer := 3;
    constant C_CTRL_BITS : integer := 5;
    constant C_UCODE_WIDTH : integer := C_SEQ_BITS + C_CTRL_BITS;

    constant SEQ_NEXT       : std_logic_vector(2 downto 0) := "000";
    constant SEQ_JMP_HIGH   : std_logic_vector(2 downto 0) := "001";
    constant SEQ_CHK_LOW    : std_logic_vector(2 downto 0) := "010";
    constant SEQ_BRANCH_SYM : std_logic_vector(2 downto 0) := "011";
    constant SEQ_CHK_RISE   : std_logic_vector(2 downto 0) := "100";
    constant SEQ_RESET      : std_logic_vector(2 downto 0) := "111";

    constant OUT_NOP          : std_logic_vector(4 downto 0) := "00000";
    constant OUT_CLR_ALL      : std_logic_vector(4 downto 0) := "00001";
    constant OUT_INC_ONE      : std_logic_vector(4 downto 0) := "00010";
    constant OUT_INC_ZERO     : std_logic_vector(4 downto 0) := "00011";
    constant OUT_CLR_CNTS     : std_logic_vector(4 downto 0) := "00100";
    constant OUT_SHIFT_DOT    : std_logic_vector(4 downto 0) := "00101";
    constant OUT_SHIFT_DASH   : std_logic_vector(4 downto 0) := "00110";
    constant OUT_SHIFT_SEP    : std_logic_vector(4 downto 0) := "00111";
    constant OUT_DECODE_CHAR  : std_logic_vector(4 downto 0) := "01000";
    constant OUT_DECODE_SPACE : std_logic_vector(4 downto 0) := "01001";

    subtype t_uAddress is integer range 0 to 15;
    type t_control_store is array(0 to 15) of std_logic_vector(C_UCODE_WIDTH - 1 downto 0);

    function to_ucode(
        seq  : std_logic_vector(C_SEQ_BITS - 1 downto 0);
        ctrl : std_logic_vector(C_CTRL_BITS - 1 downto 0)
    ) return std_logic_vector is
    begin
        return seq & ctrl;
    end function;

    function init_rom return t_control_store is
        variable rom : t_control_store := (others => (others => '0'));
    begin
        rom(0) := to_ucode(SEQ_JMP_HIGH,   OUT_CLR_ALL);
        rom(1) := to_ucode(SEQ_CHK_LOW,    OUT_INC_ONE);
        rom(2) := to_ucode(SEQ_BRANCH_SYM, OUT_NOP);
        rom(3) := to_ucode(SEQ_NEXT,       OUT_SHIFT_DOT); 
        rom(4) := to_ucode(SEQ_NEXT,       OUT_SHIFT_DASH);
        rom(5) := to_ucode(SEQ_CHK_RISE,   OUT_INC_ZERO);
        rom(6) := to_ucode(SEQ_JMP_HIGH,   OUT_SHIFT_SEP);
        rom(7) := to_ucode(SEQ_NEXT,       OUT_DECODE_CHAR); 
        rom(8) := to_ucode(SEQ_NEXT,       OUT_CLR_CNTS); 
        rom(9) := to_ucode(SEQ_RESET,      OUT_NOP);      
        rom(10) := to_ucode(SEQ_RESET,     OUT_DECODE_SPACE);

        return rom;
    end function;

    constant Control_Store : t_control_store := init_rom;

    signal uPC      : t_uAddress := 0;
    signal Next_uPC : t_uAddress;
    signal uIR      : std_logic_vector(C_UCODE_WIDTH - 1 downto 0);

begin

    process(clk, reset)
    begin
        if reset = '1' then
            uPC <= 0;
        elsif rising_edge(clk) then
            uPC <= Next_uPC;
        end if;
    end process;

    uIR <= Control_Store(uPC);

    control_signals <= uIR(C_CTRL_BITS - 1 downto 0);

    process(uPC, uIR, morse_in, flag_dash_thresh, flag_char_end, flag_space_end, flag_buff_has_data)
        variable seq_cmd : std_logic_vector(C_SEQ_BITS - 1 downto 0);
    begin
        seq_cmd := uIR(C_UCODE_WIDTH - 1 downto C_CTRL_BITS);
        
        Next_uPC <= uPC + 1;

        case seq_cmd is
            when SEQ_NEXT =>
                Next_uPC <= uPC + 1;

            when SEQ_RESET =>
                Next_uPC <= 0;

            when SEQ_JMP_HIGH =>
                if morse_in = '1' then
                    Next_uPC <= 1;
                else
                    Next_uPC <= uPC;
                end if;

            when SEQ_CHK_LOW =>
                if morse_in = '0' then
                    Next_uPC <= 2;
                else
                    Next_uPC <= uPC;
                end if;

            when SEQ_BRANCH_SYM =>
                if flag_dash_thresh = '1' then
                    Next_uPC <= 4;
                else
                    Next_uPC <= 3;
                end if;

            when SEQ_CHK_RISE =>
                if morse_in = '1' then
                    Next_uPC <= 6;
                else
                    if (flag_space_end = '1') then
                        Next_uPC <= 10;
                    elsif (flag_char_end = '1' and flag_buff_has_data = '1') then
                        Next_uPC <= 7;
                    else
                        Next_uPC <= uPC;
                    end if;
                end if;

            when others =>
                Next_uPC <= 0;
        end case;
    end process;

end architecture;