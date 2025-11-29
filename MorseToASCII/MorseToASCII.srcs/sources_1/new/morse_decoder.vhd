library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity morse_decoder is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        morse_in    : in  std_logic; 
        
        ascii_out   : out std_logic_vector(7 downto 0);
        valid_out   : out std_logic; 
        reg0        : out std_logic_vector(7 downto 0);
        reg1        : out std_logic_vector(7 downto 0);
        reg2        : out std_logic_vector(7 downto 0);
        reg3        : out std_logic_vector(7 downto 0);
        reg4        : out std_logic_vector(7 downto 0);
        reg5        : out std_logic_vector(7 downto 0);
        reg6        : out std_logic_vector(7 downto 0);
        reg7        : out std_logic_vector(7 downto 0);
        reg8        : out std_logic_vector(7 downto 0);
        reg9        : out std_logic_vector(7 downto 0);
        regA        : out std_logic_vector(7 downto 0);
        regB        : out std_logic_vector(7 downto 0);
        regC        : out std_logic_vector(7 downto 0);
        regD        : out std_logic_vector(7 downto 0);
        regE        : out std_logic_vector(7 downto 0);
        regF        : out std_logic_vector(7 downto 0)
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

    signal counter_zero      : integer;
    signal counter_one       : integer;
    
    -- Max morse code untuk ASCII : 10.
    -- Shift Register untuk Input Buffer
    signal shiftreg_inb     : unsigned(9 downto 0);
    
    -- FLAG
    
    signal NW : std_logic; --Next Word, indikasi kalimat
    signal NL : std_logic; --Next Letter
    signal FL : std_logic; -- FULL, indikasi kalau shiftreg_inb udah full

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
                        current_state <= SIGNAL_HIGH;
                    end if;

                -- State: Signal High (Mengukur 1)
                when SIGNAL_HIGH =>
                    if morse_in = '1' then
                        -- Maksimal '1' itu sama dengan thresh space.
                        if counter_one < THRESH_DASH then
                            counter_one <= counter_one + 1;
                        end if;
                    else
                        -- Signal jadi low. Analisis durasi '1' nya.
                        if counter_one < THRESH_DASH then
                            -- Input merupakan DOT ('0')
                            shiftreg_inb <= shiftreg_inb(8 downto 0) & '0';
                        else
                            -- Input merupakan DASH ('1')
                            shiftreg_inb <= shiftreg_inb(8 downto 0) & '1';
                        end if;
                        
                        counter_one <= 0;
                        current_state <= SIGNAL_LOW;
                    end if;

                -- State: Signal Low (Mengukur 0)
                when SIGNAL_LOW =>
                    if morse_in = '0' then
                        if counter_zero < THRESH_SPACE then
                            counter_zero <= counter_zero + 1;
                        end if;
                        
                        -- Cek letter timeout
                        if (counter_zero = THRESH_CHAR_END) and (shiftreg_inb > 1) then
                            current_state <= DECODE_CHAR;
                            NL <= '1';
                        -- Cek word
                        elsif counter_zero = THRESH_SPACE then
                            current_state <= DECODE_SPACE;
                            NW <= '1';
                        end if;
                    else
                        -- Signal High lagi
                        counter_one <= 0;
                        counter_zero <= 0;
                        current_state <= SIGNAL_HIGH;
                    end if;

                -- State : Decode Letter
                when DECODE_CHAR =>
                    valid_out <= '1';
                    
                   
                    case to_integer(shiftreg_inb) is
                        when 5 => ascii_out <= x"67";
                        -- ISI SELANJUTNYA 
                    end case;
                    
                    -- Reset untuk letter selanjutnya
                    shiftreg_inb <= "0000000000";
                    -- Kembali ke IDLE
                    current_state <= IDLE; 

                -- State: NEXT WORD
                when DECODE_SPACE =>
                    valid_out <= '1';
                    counter_zero   <= 0;
                    counter_one <= 0;
                    current_state <= IDLE;
                    -- __________ LOGIKA SPACE ________

            end case;
        end if;
    end process;

end architecture;
