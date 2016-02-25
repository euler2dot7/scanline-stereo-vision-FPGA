library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

package const is

-- LR UD RD(RL) "000"
-- UD RD(RL) "001"
-- UD LR "010"
-- RD(RL) LR "011"
-- LR "100"
-- RD(RL) "101" 
-- UD "110"
constant conf : std_logic_vector := "000"; 

--constant dmax	  	: integer := 16;
--constant Width 		: integer := 384;
--constant Hight		: integer := 288;

constant dmax		: integer := 64;
constant Width		: integer := 640;
constant Hight		: integer := 480;

constant P1			: integer := 10; 
constant P2			: integer := 40;
constant ADDR_WIDTH	: integer := 10;
constant DATA_WIDTH	: integer := 8;
 
constant apr		: integer := 5;

subtype LP_element is std_logic_vector(7 downto 0);
subtype LP_element_apr is std_logic_vector((7 - apr) downto 0);
subtype pixel is std_logic_vector(7 downto 0);
subtype int_4 is integer range 0 to 3;
subtype int_16 is integer range 0 to 15;
subtype int_64 is integer range 0 to dmax - 1;
subtype int_640 is integer range 0 to Width - 1;

type    GlobalCosts_array is array(dmax - 1 downto 0) of LP_element;
type    GlobalCosts_array_apr is array(dmax - 1 downto 0) of LP_element_apr;
type    Line_array is array(dmax - 1 downto 0) of pixel;
type	Address_Width_array is array (dmax - 1 downto 0) of std_logic_vector (ADDR_WIDTH - 1 downto 0);

type    d_pl0_array is array(dmax/4 - 1 downto 0) of int_4;
type    d_pl1_array is array(dmax/16 - 1 downto 0) of int_16;
type    GC0_array is array(dmax/4 - 1 downto 0) of LP_Element;
type    GC1_array is array(dmax/16 - 1 downto 0) of LP_Element;




--type	RL_Line_array is array(1 downto 0, Width - 1 downto 0) of pixel; 
--type    GlobalCosts_4_array is array(3 downto 0) of LP_element;
--type    GlobalCosts_disp_array is array(3 downto 0) of GlobalCosts_array;
--type    local_d_array is array(3 downto 0) of int_64;
--type	line_global_cost_array is array(Width - 1 downto 0) of GlobalCosts_array;
--type	line_disparity is array(Width - 1 downto 0) of std_logic_vector(7 downto 0);
--type    d_array is array(1 downto 0) of disparity_element;
--type    dtemp_array is array(2 downto 0) of disparity_element;
--type    disparity_line_array is array(Width - 1 downto 0) of disparity_element;
--type    LP_array is array(2 downto 0) of LP_element;
--type    Line_array is array(1 downto 0, dmax - 1 downto 0) of LP_element;
--subtype disparity_element is std_logic_vector(5 downto 0); 
end const; 