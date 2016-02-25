library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.const.all;

entity BRAM_WF is
port (

	clka: in std_logic;
	wea: in std_logic_vector;
	addra: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
	addrb: in std_logic_vector (ADDR_WIDTH - 1 downto 0);
	dina: in std_logic_vector	(7 downto 0 );
	doutb: out std_logic_vector (7 downto 0 )
);
end BRAM_WF;

architecture Behavorial of BRAM_WF is
	type ram_type is array ( 0 to 2**ADDR_WIDTH - 1) of std_logic_vector (7 downto 0);
	signal ram: ram_type;
	signal addra_reg, addrb_reg : std_logic_vector (ADDR_WIDTH - 1 downto 0 );
begin
	process(clka)
	begin
		if (clka'event and clka = '1' ) then
			if (wea = "1") then
				ram(to_integer(unsigned(addra))) <= dina;
			end if;
			addrb_reg <= addrb;	
		end if;
	end process;
	doutb <= ram(to_integer(unsigned(addrb_reg)));
end Behavorial;