library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        morse_in        : in  std_logic;
        
        -- Flags from Datapath
        flag_char_end   : in  std_logic; 
        flag_space_end  : in  std_logic; 
        
        -- Control Signals
        ctrl_clr_all    : out std_logic;
        ctrl_inc_one    : out std_logic;
        ctrl_inc_zero   : out std_logic;
        ctrl_proc_pulse : out std_logic; 
        ctrl_proc_gap   : out std_logic; 
        ctrl_dec_char   : out std_logic;
        ctrl_dec_space  : out std_logic
    );
end entity control_unit;

architecture microprogrammed of control_unit is

    -- [Sequence Control (3 bits)] | [Control Signals (7 bits)]
    constant C_SEQ_BITS  : integer := 3;
    constant C_CTRL_BITS : integer := 7;
    constant C_UCODE_WIDTH : integer := C_SEQ_BITS + C_CTRL_BITS;

    -- Sequence Commands
    constant SEQ_NEXT       : std_logic_vector(2 downto 0) := "000";
    constant SEQ_JMP_HIGH   : std_logic_vector(2 downto 0) := "001"; -- Jump if Input=1
    constant SEQ_CHK_FALL   : std_logic_vector(2 downto 0) := "010"; -- Check Fall (1->0)
    constant SEQ_CHK_RISE   : std_logic_vector(2 downto 0) := "011"; -- Check Rise (0->1)
    constant SEQ_GOTO_IDLE  : std_logic_vector(2 downto 0) := "100"; 
    constant SEQ_GOTO_LOW   : std_logic_vector(2 downto 0) := "101"; 

    -- Control Signal Bit Positions
    -- 6:clr, 5:inc1, 4:inc0, 3:proc_P, 2:proc_G, 1:dec_C, 0:dec_S
    
    subtype t_uAddress is integer range 0 to 15;
    type t_control_store is array(0 to 15) of std_logic_vector(C_UCODE_WIDTH - 1 downto 0);

    function ucode(
        seq : std_logic_vector(2 downto 0);
        c6, c5, c4, c3, c2, c1, c0 : std_logic
    ) return std_logic_vector is
    begin
        return seq & c6 & c5 & c4 & c3 & c2 & c1 & c0;
    end function;

    function init_rom return t_control_store is
        variable rom : t_control_store := (others => (others => '0'));
    begin
        -- 0: IDLE
        rom(0) := ucode(SEQ_JMP_HIGH, '1', '0', '0', '0', '0', '0', '0'); 
        
        -- 1: ENTRY HIGH (Transitioned from Low)
        -- Process previous Gap AND Start Incrementing One
        -- If signal falls immediately (1-cycle dot), go to ENTRY LOW (Addr 3). Else Main Loop (Addr 2).
        rom(1) := ucode(SEQ_CHK_FALL, '0', '1', '0', '0', '1', '0', '0'); 
        
        -- 2: MAIN HIGH LOOP
        -- Inc One
        rom(2) := ucode(SEQ_CHK_FALL, '0', '1', '0', '0', '0', '0', '0');

        -- 3: ENTRY LOW (Transitioned from High)
        -- Process previous Pulse AND Start Incrementing Zero
        -- If signal rises immediately (1-cycle gap), go to ENTRY HIGH (Addr 1). Else Main Loop (Addr 4).
        rom(3) := ucode(SEQ_CHK_RISE, '0', '0', '1', '1', '0', '0', '0');

        -- 4: MAIN LOW LOOP
        -- Inc Zero. Check Flags/Rise.
        rom(4) := ucode(SEQ_CHK_RISE, '0', '0', '1', '0', '0', '0', '0');

        -- 5: DECODE CHAR
        rom(5) := ucode(SEQ_GOTO_LOW, '0', '0', '0', '0', '0', '1', '0');

        -- 6: DECODE SPACE
        rom(6) := ucode(SEQ_GOTO_IDLE,'0', '0', '0', '0', '0', '0', '1');

        return rom;
    end function;

    constant Control_Store : t_control_store := init_rom;

    signal uPC      : t_uAddress := 0;
    signal Next_uPC : t_uAddress;
    signal uIR      : std_logic_vector(C_UCODE_WIDTH - 1 downto 0);
    signal seq_cmd  : std_logic_vector(2 downto 0);

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
    
    ctrl_clr_all    <= uIR(6);
    ctrl_inc_one    <= uIR(5);
    ctrl_inc_zero   <= uIR(4);
    ctrl_proc_pulse <= uIR(3);
    ctrl_proc_gap   <= uIR(2);
    ctrl_dec_char   <= uIR(1);
    ctrl_dec_space  <= uIR(0);
    
    seq_cmd <= uIR(C_UCODE_WIDTH - 1 downto C_CTRL_BITS);

    process(uPC, seq_cmd, morse_in, flag_char_end, flag_space_end)
    begin
        Next_uPC <= uPC + 1; -- Default

        case seq_cmd is
            when SEQ_NEXT => Next_uPC <= uPC + 1;
            when SEQ_GOTO_IDLE => Next_uPC <= 0;
            
            when SEQ_GOTO_LOW => 
                Next_uPC <= 4; -- Return to Main Low Loop

            when SEQ_JMP_HIGH => -- IDLE Logic
                if morse_in = '1' then 
                    Next_uPC <= 2; -- Go to Main High (Skip Entry proc logic for first pulse)
                else 
                    Next_uPC <= 0; 
                end if;

            when SEQ_CHK_FALL => -- HIGH Logic
                if morse_in = '0' then
                    Next_uPC <= 3; -- Fall detected! Go to ENTRY LOW (Process Pulse)
                else
                    Next_uPC <= 2; -- Stay in Main High
                end if;

            when SEQ_CHK_RISE => -- LOW Logic
                if morse_in = '1' then
                    Next_uPC <= 1; -- Rise detected! Go to ENTRY HIGH (Process Gap)
                else
                    if flag_space_end = '1' then
                        Next_uPC <= 6;
                    elsif flag_char_end = '1' then
                        Next_uPC <= 5;
                    else
                        Next_uPC <= 4; -- Stay in Main Low
                    end if;
                end if;

            when others => Next_uPC <= 0;
        end case;
    end process;

end architecture;
