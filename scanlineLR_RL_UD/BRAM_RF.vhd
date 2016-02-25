library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.const.all;

entity BRAM_RF is
port (
	clkA	: IN STD_LOGIC;
	wea		: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	ADDRA	: IN STD_LOGIC_VECTOR(9 DOWNTO 0);
	dina	: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	douta	: OUT STD_LOGIC_VECTOR(7 DOWNTO 0)

--	clka: in std_logic;
--	wea: in std_logic;
--	addra: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
--	dina: in std_logic_vector (N - 1 downto 0);
--	douta: out std_logic_vector (N - 1 downto 0)
);
end BRAM_RF;




architecture Behavorial of BRAM_RF is
	type ram_type is array ( 0 to 2**ADDR_WIDTH - 1) of std_logic_vector(7 downto 0);
	signal ram: ram_type;
begin
	process(clka)
	begin
		if (clka'event and clka = '1' ) then
			if (wea = "1") then
				ram(to_integer(unsigned(addra))) <= dina;
			end if;
			douta <= ram(to_integer(unsigned(addra)));
		end if;
	end process;
end Behavorial;