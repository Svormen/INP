library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- rozhrani Vigenerovy sifry
entity vigenere is
   port(
         CLK : in std_logic;
         RST : in std_logic;
         DATA : in std_logic_vector(7 downto 0);
         KEY : in std_logic_vector(7 downto 0);

         CODE : out std_logic_vector(7 downto 0)
    );
end vigenere;


architecture behavioral of vigenere is


	signal posun: std_logic_vector(7 downto 0);
	signal posun_plus: std_logic_vector(7 downto 0);
	signal posun_minus: std_logic_vector(7 downto 0);

	type stav is (plus, minus);
	signal sucasny_stav: stav := plus;
	signal dalsi_stav: stav := minus;
	signal fsm_mealy: std_logic_vector(1 downto 0);
	signal mriezka: std_logic_vector(7 downto 0) := "00100011";

begin

	---POSUNY---
	posun_process: process(DATA, KEY) is
	begin
		posun <= KEY - 64;
	end process;

	posun_plus_process: process(DATA, posun) is
		variable x: std_logic_vector(7 downto 0);
	begin
		x := DATA;
		x := (DATA + posun);
		if (x > 90) then
		       	x := x - 26;
		end if;

		posun_plus <= x;
	end process;

	posun_minus_process: process(DATA, posun) is
		variable y: std_logic_vector(7 downto 0);
	begin
		y := DATA;
		y := (DATA - posun);
		if (y < 65) then
		       	y := y + 26;
		end if;

		posun_minus <= y;
	end process;


	----MEALY----
	s_stav_reg: process(RST, CLK)
	begin
		if (RST = '1') then
			sucasny_stav <= plus;
		elsif ((CLK'event) and (CLK = '1')) then
			sucasny_stav <= dalsi_stav;
		end if;
	end process;

	d_stav_reg: process(sucasny_stav, DATA, RST)
	begin
		dalsi_stav <= sucasny_stav;

		case sucasny_stav is 
			when plus =>
				dalsi_stav <= minus;
				fsm_mealy <= "01";
			when minus =>
				dalsi_stav <= plus;
				fsm_mealy <= "10";
			when others => null;
		end case;

		if ((DATA < 58) and (DATA > 47)) then
			fsm_mealy <= "00";
		end if;

		if (RST = '1') then
			fsm_mealy <= "00";
		end if;

	end process;

	----MUX----
	multiplexor: process (posun_plus, posun_minus, mriezka, fsm_mealy) is
	begin
		case fsm_mealy is
			when "01" => CODE <= posun_plus;
			when "10" => CODE <= posun_minus;
			when others => CODE <= mriezka;
		end case;
	end process;



end behavioral;
