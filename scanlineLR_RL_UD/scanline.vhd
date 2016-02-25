library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.const.all;

entity scanline is
	Port (  
		RESET 				: in  std_logic;
		FRAME_VALID_IN 		: in  std_logic;
		LINE_VALID_IN 		: in  std_logic;
		LEFT 				: in  std_logic_vector (7 downto 0);
		RIGHT 				: in  std_logic_vector (7 downto 0);
		PIXEL_CLOCK			: in  std_logic;    
		PIPELINE_CLOCK		: in  std_logic;    
		DATA_OUT 			: out  std_logic_vector (7 downto 0);
		FRAME_VALID_OUT 	: out  std_logic;
		LINE_VALID_OUT 		: out  std_logic;
		PIXEL_VALID_OUT 	: out  std_logic
	);
end scanline;

architecture Behavioral of scanline is

	component BRAM_RF is
	port (
		CLKA	: IN STD_LOGIC;
		WEA		: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		ADDRA	: IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		DINA	: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		douta	: OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
	end component;
	
	component BRAM_WF is	
	port (
		CLKA	: IN STD_LOGIC;
		WEA		: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		ADDRA	: IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		DINA	: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
--		CLKB	: IN STD_LOGIC;
		ADDRB	: IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		DOUTB	: OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
	end component;

	signal ADDR_CG_UD_IN	: Address_Width_array;
	signal ADDR_CG_UD_OUT	: Address_Width_array;
	signal D_GC_UD_IN		: GlobalCosts_array;
	signal D_GC_UD_OUT		: GlobalCosts_array;

	signal ADDR_GC_3_IN_OUT	: Address_Width_array;
	signal D_GC_3_IN		: GlobalCosts_array;
	signal D_GC_3_OUT		: GlobalCosts_array;

	signal ADDR_DISP_UD_IN	: std_logic_vector	(ADDR_WIDTH - 1 downto 0);
	signal ADDR_DISP_UD_OUT	: std_logic_vector	(ADDR_WIDTH - 1 downto 0);
	signal D_DISP_UD_IN		: std_logic_vector	(7 downto 0 );
	signal D_DISP_UD_OUT	: std_logic_vector	(7 downto 0 );

	signal ADDR_PIXEL_LEFT_RL_IN	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal ADDR_PIXEL_LEFT_RL_OUT	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal D_PIXEL_LEFT_RL_IN		:  std_logic_vector (DATA_WIDTH - 1 downto 0 );
	signal D_PIXEL_LEFT_RL_OUT		: std_logic_vector (DATA_WIDTH - 1 downto 0 );
	
	signal ADDR_PIXEL_RIGHT_RL_IN	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal ADDR_PIXEL_RIGHT_RL_OUT	: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal D_PIXEL_RIGHT_RL_IN		: std_logic_vector (DATA_WIDTH - 1 downto 0 );
	signal D_PIXEL_RIGHT_RL_OUT		: std_logic_vector (DATA_WIDTH - 1 downto 0 );

	signal ADDR_DISP_3		: std_logic_vector (ADDR_WIDTH - 1 downto 0);
	signal D_DISP_3_IN		: std_logic_vector (7 downto 0 );
	signal D_DISP_3_OUT		: std_logic_vector (7 downto 0 );

	signal LOCAL_COST 		: GlobalCosts_array;
	signal GLOBAL_COST 		: GlobalCosts_array;
	signal GLOBAL_COST_PREV	: GlobalCosts_array;
	signal LINE_RIGHT 		: Line_array;
	signal LEFT_RL			: pixel;
	signal LINERIGHT0		: Line_array;
	signal LINERIGHT1		: Line_array;
	signal FIRST_LINE		: std_logic_vector(1 downto 0);
	signal j				: int_640; 
	signal z				: int_640;
	signal dd				: std_logic_vector(5 downto 0);
	signal i				: std_logic_vector(1 downto 0);
	signal b				: std_logic;

	signal GLOBAL_COST_TRE  : GlobalCosts_array;
	signal DPL0             : d_pl0_array;
	signal DPL1             : d_pl1_array;
	signal GC0              : GC0_array;
	signal GC1              : GC1_array;

	function comparator(A: std_logic_vector(7 downto 0); B: std_logic_vector(7 downto 0)) return boolean is
	begin
			return A(7 downto 5) > B(7 downto 5);
	end comparator;
	function comparator1(A: std_logic_vector(7 downto 0); B: std_logic_vector(7 downto 0)) return boolean is
	begin
			return A(7 downto 2) > B(7 downto 2);
	end comparator1;
begin

BRAM_loop : for k in 0 to dmax-1 generate
begin
	BramLineGlobalCostUD : BRAM_WF
		port map(
			CLKA	=> PIXEL_CLOCK,
--			CLKB		=> PIXEL_CLOCK,
			WEA		=> "1",
			ADDRA	=> ADDR_CG_UD_IN(k),
			ADDRB	=> ADDR_CG_UD_OUT(k),
			DINA	=> D_GC_UD_IN(k),
			DOUTB	=> D_GC_UD_OUT(k)
		);
	
	BramLineGlobalCostSum : BRAM_RF
		port map(
			CLKA	=> PIXEL_CLOCK,
			WEA		=> "1",
			ADDRA	=> ADDR_GC_3_IN_OUT(k),
			DINA	=> D_GC_3_IN(k),
			DOUTA	=> D_GC_3_OUT(k)
		);
end generate BRAM_loop;

BramLineDispUD : BRAM_WF
	port map(
		CLKA	=> PIXEL_CLOCK,
--		CLKB	=> PIXEL_CLOCK,
		WEA		=> "1",
		ADDRA	=> ADDR_DISP_UD_IN,
		ADDRB	=> ADDR_DISP_UD_OUT,
		DINA	=> D_DISP_UD_IN,
		DOUTB	=> D_DISP_UD_OUT 
	);

BramLineLeft : BRAM_RF
	port map(
		CLKA	=> PIXEL_CLOCK,
		WEA		=> "1",
		ADDRA	=> ADDR_PIXEL_LEFT_RL_IN,
		DINA	=> D_PIXEL_LEFT_RL_IN ,
		DOUTA	=> D_PIXEL_LEFT_RL_OUT 
	);

BramLineRight : BRAM_WF
	port map(
		CLKA	=> PIXEL_CLOCK,
--		CLKB	=> PIXEL_CLOCK,
		WEA		=> "1",
		ADDRA	=> ADDR_PIXEL_RIGHT_RL_IN,
		ADDRB	=> ADDR_PIXEL_RIGHT_RL_OUT,
		DINA	=> D_PIXEL_RIGHT_RL_IN ,
		DOUTB	=> D_PIXEL_RIGHT_RL_OUT 
	);
		
BramLineDisp : BRAM_RF
	port map(
		CLKA	=> PIXEL_CLOCK,
		WEA		=> "1",
		ADDRA	=> ADDR_DISP_3,
		DINA	=> D_DISP_3_IN,
		DOUTA 	=> D_DISP_3_OUT 
	);

ID : process(PIXEL_CLOCK) is

begin
	if PIXEL_CLOCK = '1' and PIXEL_CLOCK'EVENT then
		if RESET = '1' or  FRAME_VALID_IN = '0'  then
			FRAME_VALID_OUT <= '0';
			LINE_VALID_OUT <= '0';
			PIXEL_VALID_OUT <= '0';
			j <= 0;
			z <= 0;
			b <= '0';
			FIRST_LINE <= "00";
			ADDR_CG_UD_OUT <= (others =>(others => '0'));
			ADDR_CG_UD_IN <= (others =>(others => '0'));
			ADDR_DISP_UD_IN	<=(others => '0');
			ADDR_DISP_UD_OUT <=(others => '0');
			ADDR_DISP_3 <= (others => '0');
			ADDR_GC_3_IN_OUT <= (others =>(others => '0'));
		else
				FRAME_VALID_OUT <= '1';
				if LINE_VALID_IN = '1' then
					LINE_VALID_OUT <= '1';					
					PIXEL_VALID_OUT <= '1';					
					j <= j + 1;
					if b = '0' then
						z <= j;
					else
						z <= Width - j - 1;
					end if;
					ADDR_DISP_3 <= conv_std_logic_vector(z, ADDR_WIDTH);
					ADDR_GC_3_IN_OUT <= (others => conv_std_logic_vector(z, ADDR_WIDTH));
					ADDR_CG_UD_OUT <= (others => conv_std_logic_vector(j + 1,ADDR_WIDTH));
					ADDR_CG_UD_IN <= (others => conv_std_logic_vector(j - 1,ADDR_WIDTH));
					ADDR_DISP_UD_IN	<=conv_std_logic_vector(j - 1, ADDR_WIDTH);
					ADDR_DISP_UD_OUT <=conv_std_logic_vector(j + 1, ADDR_WIDTH);
					if FIRST_LINE = "00" then
						ADDR_CG_UD_IN <=(others => conv_std_logic_vector(j + 1,ADDR_WIDTH));
						ADDR_DISP_UD_IN <=conv_std_logic_vector(j + 1, ADDR_WIDTH);
					end if;					
				else
					if j = Width then
						b <= not b;
						if FIRST_LINE = "00" then
							FIRST_LINE <= "01";
						elsif FIRST_LINE = "01" then
							FIRST_LINE <= "10";
						elsif FIRST_LINE = "10" then
							FIRST_LINE <= "11";
						end if;
					end if;
					LINE_VALID_OUT <= '0';					
					PIXEL_VALID_OUT <= '0';					
					j <= 0;
				end if;
		end if; --RESET			
	end if; -- PIXEL CLOCK
end process ID;


F : process(PIPELINE_CLOCK) is
	variable LeftRL			: pixel;
	variable LineRightLR 	: Line_array;
begin
	if(PIPELINE_CLOCK'EVENT and PIPELINE_CLOCK = '1') then
		if RESET = '1' or  FRAME_VALID_IN = '0'  then
			LINERIGHT0	<= (others =>(others => '0'));
			LINERIGHT1	<= (others =>(others => '0'));
			LINE_RIGHT	<= (others =>(others => '0'));
			LEFT_RL		<= (others => '0');
			D_PIXEL_LEFT_RL_IN <= (others => '0');
			D_PIXEL_RIGHT_RL_IN <= (others => '0');
			ADDR_PIXEL_LEFT_RL_IN <= (others => '0');
			ADDR_PIXEL_RIGHT_RL_IN <= (others => '0');
			ADDR_PIXEL_RIGHT_RL_OUT <= (others => '0');
			D_PIXEL_LEFT_RL_IN <= (others => '0');
			D_PIXEL_RIGHT_RL_IN <= (others => '0');
			LineRightLR := (others =>(others => '0'));
			LeftRL := (others => '0');
			i <= "00";
		elsif LINE_VALID_IN = '1' then
			if(i = "01") then
				LineRightLR := LineRightLR(dmax - 2 downto 0) & RIGHT;
				LINE_RIGHT <= LineRightLR;
				LEFT_RL <= LEFT;
			elsif(i = "11") then
				if b = '0' then
					ADDR_PIXEL_LEFT_RL_IN <= conv_std_logic_vector(j  , ADDR_WIDTH);
					ADDR_PIXEL_RIGHT_RL_IN <= conv_std_logic_vector(j , ADDR_WIDTH);
					ADDR_PIXEL_RIGHT_RL_OUT <= conv_std_logic_vector(j  + dmax, ADDR_WIDTH);
					if j  < Width - dmax then
						LINERIGHT0 <= D_PIXEL_RIGHT_RL_OUT & LINERIGHT0(dmax - 1 downto 1);
					else
						ADDR_PIXEL_RIGHT_RL_OUT <= conv_std_logic_vector(Width - 1, ADDR_WIDTH);
						LINERIGHT0 <= "00000000" & LINERIGHT0(dmax - 1 downto 1);
					end if;
					LINERIGHT1 <= LINERIGHT1(dmax - 2 downto 0) & RIGHT;
					LINE_RIGHT <= LINERIGHT0;
				else
					ADDR_PIXEL_LEFT_RL_IN <= conv_std_logic_vector(Width - j - 1, ADDR_WIDTH);
					ADDR_PIXEL_RIGHT_RL_IN <= conv_std_logic_vector(Width - j - 1, ADDR_WIDTH);
					ADDR_PIXEL_RIGHT_RL_OUT <= conv_std_logic_vector(Width - j - 1 - dmax, ADDR_WIDTH);
					if  j < Width - 1 - dmax then
						LINERIGHT1 <= D_PIXEL_RIGHT_RL_OUT & LINERIGHT1(dmax - 1 downto 1);
					else
						ADDR_PIXEL_RIGHT_RL_OUT <= conv_std_logic_vector(0, ADDR_WIDTH);
						LINERIGHT1 <= "00000000" & LINERIGHT1(dmax - 1 downto 1);
					end if;                         
					LINERIGHT0 <= LINERIGHT0( dmax - 2 downto 0) & RIGHT  ;
					LINE_RIGHT <= LINERIGHT1;
				end if;
				LeftRL :=  D_PIXEL_LEFT_RL_OUT;
				D_PIXEL_LEFT_RL_IN <= LEFT;
				D_PIXEL_RIGHT_RL_IN <= RIGHT;
				LEFT_RL <= LeftRL;
				if FIRST_LINE /= "11" then
					LEFT_RL <= (others => '0');
					LINE_RIGHT <= (others => (others => '0'));
				end if;
			end if; -- i
			i <= i + 1; 
		end if;	--line valid / reset
	end if;
end process f;

LOCAL_EX_loop : for k in 0 to dmax-1 generate
begin
	LOCAL_EX : process(PIPELINE_CLOCK) is
		variable LocalCost : LP_element;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT then
			if RESET = '1' or  FRAME_VALID_IN = '0'  then
				LocalCost := (others => '0');
				LOCAL_COST(k) <= LocalCost;
			elsif LINE_VALID_IN = '1'  then
				if (LEFT_RL > LINE_RIGHT(k) )then
					LocalCost := (LEFT_RL - LINE_RIGHT(k));
				else
					LocalCost := (LINE_RIGHT(k) - LEFT_RL);
				end if;
				LOCAL_COST(k) <= LocalCost;
			end if;
		end if;	
	end process LOCAL_EX;
end generate LOCAL_EX_loop;

GLOBAL_EX_loop : for k in 1 to dmax-2 generate
begin	
	EX : process(PIPELINE_CLOCK) is
		variable LP		: LP_element ;
		variable GCP	: LP_element ;
		variable nn		: int_64;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT then
			if RESET = '1' or  FRAME_VALID_IN = '0'  then
				GLOBAL_COST(k) <= (others => '0');
				nn	:= 0;
				LP	:= (others => '0');
				GCP	:= (others => '0');
			elsif LINE_VALID_IN = '1' then
				nn	:= k - 1;
				LP := GLOBAL_COST_PREV(k);
				GCP := GLOBAL_COST_PREV(conv_integer(dd));
				if(comparator(GLOBAL_COST_PREV(k - 1),GLOBAL_COST_PREV(k + 1))) then
					nn := k + 1;
				end if;
				if(comparator(LP,GLOBAL_COST_PREV(nn) + P1)) then
					if(comparator(GLOBAL_COST_PREV(nn) + P1,P2 + GCP)) then
						GLOBAL_COST(k) <= LOCAL_COST(k) + P2 ;
					else
						GLOBAL_COST(k) <= LOCAL_COST(k) + GLOBAL_COST_PREV(nn) + P1 - GCP;
					end if;
				else 	
					if(comparator(LP,P2 + GCP)) then
						GLOBAL_COST(k) <= LOCAL_COST(k) + P2  ;
					else
						GLOBAL_COST(k) <= LOCAL_COST(k) + LP - GCP;
					end if;
				end if;		
			end if; --RESET		
		end if; --PIXEL_CLOCK
	end process EX;
end generate GLOBAL_EX_loop;

EX0 : process(PIPELINE_CLOCK) is
	variable LP : LP_element := (others => '0');
	variable GCP	: LP_element ;
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' or  FRAME_VALID_IN = '0'  then
				GLOBAL_COST(0) <= (others => '0');
				LP := (others => '0');				
		elsif LINE_VALID_IN = '1'  then
			LP := GLOBAL_COST_PREV(0);
			GCP := GLOBAL_COST_PREV(conv_integer(dd));
			if(comparator(LP,GLOBAL_COST_PREV(1) + P1)) then
				LP := GLOBAL_COST_PREV(1) + P1;
			end if;				
			if(comparator(LP,P2 + GCP)) then
				LP := P2 + GCP;
			end if;
			GLOBAL_COST(0) <= LOCAL_COST(0) + LP - GCP;
		end if; --RESET		
	end if; --PIXEL_CLOCK
end process EX0;

EXDmax : process(PIPELINE_CLOCK) is
	variable LP : LP_element := (others => '0');
	variable GCP	: LP_element ;
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' or  FRAME_VALID_IN = '0'  then
			LP := (others => '0');
			GLOBAL_COST(dmax - 1) <= (others => '0');
		elsif LINE_VALID_IN = '1'  then
			LP := GLOBAL_COST_PREV(dmax - 1);
			GCP := GLOBAL_COST_PREV(conv_integer(dd));
			if(comparator(GLOBAL_COST_PREV(dmax - 1),GLOBAL_COST_PREV(dmax - 2) + P1)) then
				LP := GLOBAL_COST_PREV(dmax - 2) + P1;
			end if;				
			if(comparator(LP,P2 + GCP)) then
				LP := P2 + GCP ;
			end if;
			GLOBAL_COST(dmax - 1) <= LOCAL_COST(dmax - 1) + LP - GCP;
		end if; --RESET		
	end if; --PIXEL_CLOCK
end process EXDmax;


PL0 : for k in 0 to dmax/4 - 1 generate
begin
	DPL00 : process(PIPELINE_CLOCK) is      
	variable d              : int_64;
	variable GlobalCost     : GlobalCosts_array;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
			if RESET = '1' or  FRAME_VALID_IN = '0'  then
				dpl0(k) <= 0;
				GC0(k)  <= (others => '0');
				GlobalCost := (others => (others => '0'));
			elsif LINE_VALID_IN = '1' then  
				if i = "11" then
					GlobalCost := GLOBAL_COST_TRE;                                  
				else
					GlobalCost := GLOBAL_COST;
				end if;
				d := 4 * k;
				for z in 4 * k + 1 to 4 * k + 3 loop
					if(comparator1(GlobalCost(d), GlobalCost(z))) then
						d := z;
					end if;
				end loop;                               
				dpl0(k) <= d - 4 * k;
				GC0(k)  <= GlobalCost(d);
			end if;
		end if; 
	end process DPL00;
end generate PL0;

PL1 : for k in 0 to dmax/16 - 1 generate
begin
	DPL01 : process(PIPELINE_CLOCK) is      
	variable d      : int_64;
	begin
		if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
			if RESET = '1' or  FRAME_VALID_IN = '0'  then
				dpl1(k) <= 0;
				GC1(k)  <= (others => '0');
			elsif LINE_VALID_IN = '1' then                                  
				d := k * 4;
				for z in k * 4 + 1 to k * 4 + 3 loop
					if comparator1(GC0(d), GC0(z)) then
						d := z;
					end if;
				end loop;                               
				dpl1(k) <= 4 * (d - k * 4) + dpl0(d);
				GC1(k)  <= GC0(d);                                                      
			end if;
		end if;         
	end process DPL01;
end generate PL1;
 
DISP : process(PIPELINE_CLOCK) is       
		variable d						: int_4;
		variable dpl					: int_64;
		variable dRL                    : int_64;
		variable dLR                    : int_64;
		variable dUD                    : int_64;
	begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' or  FRAME_VALID_IN = '0'  then
			dd              <= (others => '0');
			DATA_OUT        <= (others => '0');
			dpl := 0;
			dUD := 0;
			dRL := 0;
			dLR := 0;
			D_DISP_UD_IN	<= (others => '0');
			D_DISP_3_IN		<= (others => '0');
		elsif LINE_VALID_IN = '1'   then
			d := 0;
			for z in 0 to dmax / 16 - 1 loop
				if(GC1(d)> GC1(z)) then
					d := z;
				end if;                         
			end loop;
			dpl := dpl1(d) + d * 16;
			if  i = "00" then                                                               
					dRL := dpl;
					dd <= conv_std_logic_vector(dRL, 6);
			elsif  i = "01" then
				if FIRST_LINE = "00" then
					D_DISP_3_IN		<= (others => '0');
					DATA_OUT		<= (others => '0');
				else
					D_DISP_3_IN     <= conv_std_logic_vector(dpl, 8);
				end if;
				if (conf = "000" or conf = "101" or conf = "001" or conf = "011" or conf = "010" ) and FIRST_LINE /= "00" then
					DATA_OUT <= D_DISP_3_OUT(5 downto 0) & "00";
				end if;
			elsif  i = "10" then
				D_DISP_UD_IN    <= conv_std_logic_vector(dpl, 8);
				if FIRST_LINE = "00" then                               
					dUD := 0;
				else
					dUD := conv_integer(D_DISP_UD_OUT);
				end if;
				
				if conf = "110" and FIRST_LINE /= "00" then
					DATA_OUT <= conv_std_logic_vector(dUD, 6) & "00";
				end if;
				
				dd <= conv_std_logic_vector(dUD, 6);
			elsif  i = "11" then
				dLR := dpl;
				if conf = "100" and FIRST_LINE /= "00" then
					DATA_OUT <= conv_std_logic_vector(dLR, 6) & "00";
				end if;
				dd <= conv_std_logic_vector(dLR, 6);
			end if; --i
		end if; --line valid
	end if; --reset
end process DISP;

GCPP : process(PIPELINE_CLOCK) is	
	variable GlobalCostRL	: GlobalCosts_array;
	variable GlobalCostLR	: GlobalCosts_array;
	variable GlobalCostUD 	: GlobalCosts_array;
	variable GlobalCost3	: GlobalCosts_array;
begin
	if PIPELINE_CLOCK = '1' and PIPELINE_CLOCK'EVENT  then
		if RESET = '1' or  FRAME_VALID_IN = '0'  then
			GLOBAL_COST_PREV	<= (others =>(others => '0'));
			GLOBAL_COST_TRE		<= (others =>(others => '0'));
			D_GC_3_IN			<= (others =>(others => '0'));
			D_GC_UD_IN			<= (others =>(others => '0'));
			GlobalCostRL	:=	(others =>(others => '0'));
			GlobalCostUD	:=	(others =>(others => '0'));
			GlobalCostLR	:=	(others =>(others => '0'));
			GlobalCost3		:=	(others =>(others => '0'));
		elsif LINE_VALID_IN = '1'   then
				if FIRST_LINE = "00" then
					GlobalCostUD := (others =>(others => '0'));             
				else
					GlobalCostUD := D_GC_UD_OUT;
				end if;
			if  i = "00" then								
				D_GC_UD_IN			<= GLOBAL_COST;
				GLOBAL_COST_PREV	<= GlobalCostRL;
				if conf /= "011" then
					for k in 0 to dmax - 1 loop
						GlobalCost3(k) := GlobalCost3(k) + GlobalCostUD(k)(7 downto 2);
					end loop;
				end if;				
			elsif  i = "01" then								
				GlobalCostLR := GLOBAL_COST;
				if conf /= "001" then
					for k in 0 to dmax - 1 loop
						GlobalCost3(k) := GlobalCost3(k) + GlobalCostLR(k)(7 downto 2);
					end loop;	
				end if;
			elsif  i = "10" then								
				GlobalCostRL := GLOBAL_COST;
				GLOBAL_COST_PREV <= GlobalCostUD;
				D_GC_3_IN <= GlobalCost3;

				if conf = "101" then
					GlobalCost3 := GlobalCostRL;
				elsif conf /= "010" and FIRST_LINE /= "00" and FIRST_LINE /= "01"  then
					for k in 0 to dmax - 1 loop
						GlobalCost3(k) := D_GC_3_OUT(k) + GlobalCostRL(k)(7 downto 2);
					end loop;				
				end if;
				GLOBAL_COST_TRE <= GlobalCost3;
			elsif  i = "11" then								
				GLOBAL_COST_PREV <= GlobalCostLR;
				GlobalCost3 := (others =>(others => '0'));
			end if;
		end if;
	end if;
end process GCPP;

end Behavioral;