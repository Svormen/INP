-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2020 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): DOPLNIT
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WE    : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti 
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

	-- PC
	signal pc_reg : std_logic_vector(11 downto 0);
	signal pc_inc : std_logic;
	signal pc_dec : std_logic;
	signal pc_ld : std_logic;

	-- RAS
	signal ras_reg : std_logic_vector(11 downto 0);

	-- PTR
	signal ptr_reg : std_logic_vector(9 downto 0);
	signal ptr_inc : std_logic;
	signal ptr_dec : std_logic;

	-- MUX
	signal mx_wdata : std_logic_vector(7 downto 0);
	signal mx_wdata_sel : std_logic_vector(1 downto 0) := "00";

	-- STATES
	type fsm_state is (s_init, s_ifetch, s_idecode, 
			s_data_inc, s_data_inc_mx, s_data_inc_n,
			s_data_dec, s_data_dec_mx, s_data_dec_n,
			s_ptr_inc, s_ptr_dec,	
			s_while_start, s_while_start_n, s_while_start_n2, s_while_start_l,
			s_while_end,
			s_put, s_put_n,
			s_get, s_get_n,
			s_halt,
			s_others);

	signal f_state : fsm_state := s_init;
	signal f_nstate : fsm_state;

	
begin

	-- PC
	pc: process (CLK, RESET, pc_inc, pc_dec, pc_ld)
	begin
		if (RESET = '1') then
			pc_reg <= (others => '0');
		elsif (CLK'event) and (CLK='1') then
			if (pc_inc = '1') then
				pc_reg <= pc_reg + 1;
			elsif (pc_dec = '1') then
				pc_reg <= pc_reg - 1;
			elsif (pc_ld = '1') then
				pc_reg <= ras_reg;
			end if;
		end if;
	end process;
	CODE_ADDR <= pc_reg;

	-- PTR
	ptr: process (CLK, RESET, ptr_inc, ptr_dec)
	begin
		if (RESET = '1') then
			ptr_reg <= (others => '0');
		elsif (CLK'event) and (CLK='1') then
			if (ptr_inc = '1') then
				ptr_reg <= ptr_reg + 1;
			elsif (ptr_dec = '1') then
				ptr_reg <= ptr_reg - 1;
			end if;
		end if;
	end process;
	DATA_ADDR <= ptr_reg;

	-- MUX
	mx: process (CLK, RESET, mx_wdata_sel)
	begin
		if (RESET = '1') then
			mx_wdata <= (others => '0');
		elsif (CLK'event) and (CLK='1') then
			case mx_wdata_sel is
				when "00" =>
					mx_wdata <= IN_DATA;
				when "01" =>
					mx_wdata <= DATA_RDATA + 1;
				when "10" =>
					mx_wdata <= DATA_RDATA - 1;
				when others =>
					mx_wdata <= (others => '0');
			end case;
		end if;
	end process;
	DATA_WDATA <= mx_wdata;

	-- FSM
	fsm_pstate: process(CLK, RESET, EN)
	begin
		if (RESET = '1') then
			f_state <= s_init;
		elsif (CLK'event) and (CLK='1') then
			if (EN = '1') then
				f_state <= f_nstate;
			end if;
		end if;
	end process;

	fsm_nstate: process (f_state, OUT_BUSY, IN_VLD, CODE_DATA, DATA_RDATA)
	begin
		-- ROM
		CODE_EN <= '0';
		-- I/O
		IN_REQ <= '0';
		OUT_WE <= '0';
		-- PC
		pc_inc <= '0';
		pc_dec <= '0';
		pc_ld <= '0';
		-- PTR
		ptr_inc <= '0';
		ptr_dec <= '0';
		-- MUX
		mx_wdata_sel <= "00";
		-- RAM
		DATA_WE <= '0';
		DATA_EN <= '0';

		case f_state is 
			when s_init =>
				f_nstate <= s_ifetch;
			when s_ifetch =>
				CODE_EN <= '1';
				f_nstate <= s_idecode;
			when s_idecode =>
				case CODE_DATA is
					when X"3E" =>
						f_nstate <= s_ptr_inc;
					when X"3C" =>
						f_nstate <= s_ptr_dec;
					when X"2B" =>
						f_nstate <= s_data_inc;
					when X"2D" =>
						f_nstate <= s_data_dec;
					when X"5B" =>
						f_nstate <= s_while_start;
					when X"5D" =>
						f_nstate <= s_while_end;
					when X"2E" =>
						f_nstate <= s_put;
					when X"2C" =>
						f_nstate <= s_get;
					when X"00" =>
						f_nstate <= s_halt;
					when others =>
						f_nstate <= s_others; 
				end case;

			when s_ptr_inc =>
				ptr_inc <= '1';
				pc_inc <= '1';
				f_nstate <= s_ifetch;

			when s_ptr_dec =>
				ptr_dec <= '1';
				pc_inc <= '1';
				f_nstate <= s_ifetch;

			when s_data_inc =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				f_nstate <= s_data_inc_mx;

			when s_data_inc_mx =>
				mx_wdata_sel <= "01";
				f_nstate <= s_data_inc_n;

			when s_data_inc_n =>
				DATA_EN <= '1';
				DATA_WE <= '1';
				pc_inc <= '1';
				f_nstate <= s_ifetch;

			when s_data_dec =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				f_nstate <= s_data_dec_mx;

			when s_data_dec_mx =>
				mx_wdata_sel <= "10";
				f_nstate <= s_data_dec_n;

			when s_data_dec_n =>
				DATA_EN <= '1';
				DATA_WE <= '1';
				pc_inc <= '1';
				f_nstate <= s_ifetch;
			
			when s_while_start =>
				pc_inc <= '1';
				DATA_EN <= '1';
				DATA_WE <= '0';
				f_nstate <= s_while_start_n;
			
			when s_while_start_n =>
				if DATA_RDATA = (DATA_RDATA'range => '0') then
					CODE_EN <= '1';
					f_nstate <= s_while_start_n2;
				else
					ras_reg <= pc_reg;
					f_nstate <= s_ifetch;
				end if;

			when s_while_start_n2 =>
				pc_inc <= '1';
				if (CODE_DATA = X"5D") then
					ras_reg <= (others => '0');
					f_nstate <= s_ifetch;
				else
					f_nstate <= s_while_start_l;
			end if;
				
			when s_while_start_l =>
				CODE_EN <= '1';
				f_nstate <= s_while_start_n2;

			when s_while_end =>
				if DATA_RDATA = (DATA_RDATA'range => '0') then
					pc_inc <= '1';
					f_nstate <= s_ifetch;
				else
					pc_ld <= '1';
					f_nstate <= s_ifetch;
				end if;

			when s_put =>
				DATA_EN <= '1';
				DATA_WE <= '0';
				f_nstate <= s_put_n;

			when s_put_n =>
				if (OUT_BUSY = '1') then
					DATA_EN <= '1';
					DATA_WE <= '0';
					f_nstate <= s_put_n;
				else
					OUT_WE <= '1';
					pc_inc <= '1';
					OUT_DATA <= DATA_RDATA;
					f_nstate <= s_ifetch;
				end if;

			when s_get =>
				IN_REQ <= '1';
				mx_wdata_sel <= "00";
				f_nstate <= s_get_n;
			when s_get_n =>
				if (IN_VLD /= '1') then
					IN_REQ <= '1';
					mx_wdata_sel <= "00";
					f_nstate <= s_get_n;
				else
					DATA_EN <= '1';
					DATA_WE <= '1';
					pc_inc <= '1';
					f_nstate <= s_ifetch;
				end if;

			when s_others =>
				pc_inc <= '1';
				f_nstate <= s_ifetch;

			when s_halt =>
				f_nstate <= s_halt;

			when others =>
				null;

		end case;


	end process;



end behavioral;
 
