library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;


package gestioneBmp is

  -- quantità massima di memoria
  constant cMAX_X         : integer := 700;--Massima larghezza immagine
  constant cMAX_Y         : integer := 500;--Massima altezza immagine
  

  constant cMaxMemSize : integer := cMAX_X * cMAX_Y * 3;

  subtype file_element is std_logic_vector(7 downto 0);
  type    mem_array is array(cMaxMemSize downto 0) of file_element;
  type    header_array is array(53 downto 0) of file_element;

	--procedura per leggere un file bmp
	procedure ReadFile_R(FileName  : in string);
	--procedura per scrivere un file bmp
	procedure WriteFile_R(FileName : in string);
	--Legge la larghezza dell'immagine dall'header del file
	function GetWidth_R(header        : in  header_array) return integer;
	--Procedura usata dall'esterno per conoscere la larghezza dell'immagine appena letta
	procedure GetWidth_R(signal width : out integer);
	--Legge l'altezza dell'immagine dall'header del file
	function GetHeigth_R(header         : in  header_array) return integer;
	--Procedura usata dall'esterno per conoscere l'altezza dell'immagine appena letta
	procedure GetHeigth_R(signal height : out integer);
	--per immagini a colori
	procedure GetPixel_R(x : in integer; y : in integer; signal data : out std_logic_vector(23 downto 0));
	procedure SetPixel_R(x : in integer; y : in integer; signal data : in std_logic_vector(23 downto 0));
	--per immagini in bianco e nero
	procedure GetGrayPixel_R(x : in integer; y : in integer; signal data : out std_logic_vector(7 downto 0));
	procedure SetGrayPixel_R(x : in integer; y : in integer; signal data : in std_logic_vector(7 downto 0));
	
----------------------------------- ALTRA IMMAGINE ---------------------------------  
  
  --procedura per leggere un file bmp
	procedure ReadFile_L(FileName  : in string);
	--procedura per scrivere un file bmp
	procedure WriteFile_L(FileName : in string);
	--Legge la larghezza dell'immagine dall'header del file
	function GetWidth_L(header1        : in  header_array) return integer;
	--Procedura usata dall'esterno per conoscere la larghezza dell'immagine appena letta
	procedure GetWidth_L(signal width : out integer);
	--Legge l'altezza dell'immagine dall'header del file
	function GetHeigth_L(header1         : in  header_array) return integer;
	--Procedura usata dall'esterno per conoscere l'altezza dell'immagine appena letta
	procedure GetHeigth_L(signal height : out integer);
	--per immagini a colori
	procedure GetPixel_L(x : in integer; y : in integer; signal data : out std_logic_vector(23 downto 0));
	procedure SetPixel_L(x : in integer; y : in integer; signal data : in std_logic_vector(23 downto 0));
	--per immagini in bianco e nero
	procedure GetGrayPixel_L(x : in integer; y : in integer; signal data : out std_logic_vector(7 downto 0));
	procedure SetGrayPixel_L(x : in integer; y : in integer; signal data : in std_logic_vector(7 downto 0));

  
end package gestioneBmp;



package body gestioneBmp is

  shared variable memory_in_R : mem_array;
  shared variable memory_out_R : mem_array;

  shared variable memory_in_L  : mem_array;
  shared variable memory_out_L : mem_array;

  shared variable header : header_array;

  shared variable pImageSize   : integer;
  shared variable pImageWidth  : integer;
  shared variable pImageHeight : integer;
  
  shared variable header1 : header_array;

  shared variable pImageSize1  : integer;
  shared variable pImageWidth1  : integer;
  shared variable pImageHeight1 : integer;


  --lettura file
  procedure ReadFile_R(FileName : in string) is

    variable next_vector : bit_vector (0 downto 0);
    variable actual_len  : natural;
    variable index       : integer := 0;
    type     bit_vector_file is file of bit_vector;
    file read_file       : bit_vector_file open read_mode is FileName;

  begin
    report "Lettura File";
    report FileName;
    index := 0;
	 actual_len:=0;

    -- Lettura Header
    report "Lettura Header";
    for i in 0 to 53 loop
      read(read_file, next_vector, actual_len);

      if actual_len > next_vector'length then
        report "vettore troppo lungo";
      else
        header(index) := conv_std_logic_vector(bit'pos(next_vector(0)), 8);
        index         := index + 1;
      end if;
    end loop;

    pImageWidth  := GetWidth_R(header);
    pImageHeight := GetHeigth_R(header);
    pImageSize   := pImageWidth * pImageHeight;

    report "Lettura Immagine";
    index := 0;
    while not endfile(read_file) loop
      read(read_file, next_vector, actual_len);
      if actual_len > next_vector'length then
        report "vettore troppo lungo";
      else
			memory_in_R(index)  := conv_std_logic_vector(bit'pos(next_vector(0)), 8);
			memory_out_R(index) := x"45";
         index             := index + 1;
      end if;
    end loop;

    report "Lettura Okay";
  end ReadFile_R;


  -- operazioni sui pixel
  procedure GetPixel_R(x : in integer; y : in integer; signal data : out std_logic_vector(23 downto 0)) is
  begin
    if x >= 0 and x < cMAX_X and y >= 0 and y < cMAX_Y then
      data(23 downto 16) <= memory_in_R(x*3 + 3*(pImageHeight-y-1)*GetWidth_R(header));
      data(15 downto 8)  <= memory_in_R(x*3+1 + 3*(pImageHeight-y-1)*GetWidth_R(header));
      data(7 downto 0)   <= memory_in_R(x*3+2 + 3*(pImageHeight-y-1)*GetWidth_R(header));
    end if;
  end GetPixel_R;
  
  procedure GetGrayPixel_R(x : in integer; y : in integer; signal data : out std_logic_vector(7 downto 0)) is
  begin
    if x >= 0 and x < cMAX_X and y >= 0 and y < cMAX_Y then
		data(7 downto 0) <= memory_in_R(x*3+2 + 3*(pImageHeight-y-1)*GetWidth_R(header));
    end if;
  end GetGrayPixel_R;

  procedure SetPixel_R(x : in integer; y : in integer; signal data : in std_logic_vector(23 downto 0)) is
  begin
    if x >= 0 and x < cMAX_X and y >= 0 and y < cMAX_Y then
      memory_out_R(x*3+(pImageHeight-y-1)*(GetWidth_R(header)*3))   := data(23 downto 16);
      memory_out_R(x*3+1+(pImageHeight-y-1)*(GetWidth_R(header)*3)) := data(15 downto 8);
      memory_out_R(x*3+2+(pImageHeight-y-1)*(GetWidth_R(header)*3)) := data(7 downto 0);
    end if;
  end SetPixel_R;
 
  procedure SetGrayPixel_R(x : in integer; y : in integer; signal data : in std_logic_vector(7 downto 0)) is
  begin
    if x >= 0 and x < cMAX_X and y >= 0 and y < cMAX_Y then
			memory_out_R(x*3+(pImageHeight-y-1)*(GetWidth_R(header)*3))   := data(7 downto 0);
			memory_out_R(x*3+1+(pImageHeight-y-1)*(GetWidth_R(header)*3)) := data(7 downto 0);
			memory_out_R(x*3+2+(pImageHeight-y-1)*(GetWidth_R(header)*3)) := data(7 downto 0);
	    end if;
  end SetGrayPixel_R;


  -- larghezza immagine
  function GetWidth_R(header : in header_array) return integer is
  begin
    return conv_integer(header(21) & header(20) & header(19) & header(18));
  end function GetWidth_R;

  procedure GetWidth_R(signal width : out integer) is
  begin
    width <= pImageWidth;
  end GetWidth_R;

  -- altezza immagine
  function GetHeigth_R(header : in header_array) return integer is
  begin
    return conv_integer(header(25) & header(24) & header(23) & header(22));
  end function GetHeigth_R;

  procedure GetHeigth_R(signal height : out integer) is
  begin
    height <= pImageHeight;
  end GetHeigth_R;

	
	--Scrittura file
  procedure WriteFile_R(FileName : in string) is

    variable next_vector : character;
    variable index       : integer := 0;
    type     char_file is file of character;
    file write_file      : char_file open write_mode is FileName;

  begin
    report "Scrittura File...";
    report FileName;

    report "Scrittura Header";
    index := 0;
    for i in 0 to 53 loop
      next_vector := character'val(conv_integer(header(index)));
      write(write_file, next_vector);
      index       := index + 1;
    end loop;


    report "Scrittura immagine";
    index := 0;
    while index < pImageSize*3 loop
		next_vector := character'val(conv_integer(memory_out_R(index)));
		write(write_file, next_vector);
		index       := index + 1;
    end loop;

    report "Scrittura Okay";

  end WriteFile_R;
  
  -------------------------- ALTRA IMMAGINE ------------------------------
  
  --lettura file
  procedure ReadFile_L(FileName : in string) is

    variable next_vector : bit_vector (0 downto 0);
    variable actual_len  : natural;
    variable index       : integer := 0;
    type     bit_vector_file is file of bit_vector;
    file read_file       : bit_vector_file open read_mode is FileName;

  begin
    report "Lettura File";
    report FileName;
    index := 0;
	 actual_len:=0;

    -- Lettura Header
    report "Lettura Header";
    for i in 0 to 53 loop
      read(read_file, next_vector, actual_len);

      if actual_len > next_vector'length then
        report "vettore troppo lungo";
      else
        header1(index) := conv_std_logic_vector(bit'pos(next_vector(0)), 8);
        index         := index + 1;
      end if;
    end loop;

    pImageWidth1  := GetWidth_L(header1);
    pImageHeight1 := GetHeigth_L(header1);
    pImageSize1   := pImageWidth1 * pImageHeight1;

    report "Lettura Immagine";
    index := 0;
    while not endfile(read_file) loop
      read(read_file, next_vector, actual_len);
      if actual_len > next_vector'length then
        report "vettore troppo lungo";
      else
			memory_in_L(index)  := conv_std_logic_vector(bit'pos(next_vector(0)), 8);
			memory_out_L(index) := x"45";
         index             := index + 1;
      end if;
    end loop;

    report "Lettura Okay";
  end ReadFile_L;


  -- operazioni sui pixel
  procedure GetPixel_L(x : in integer; y : in integer; signal data : out std_logic_vector(23 downto 0)) is
  begin
    if x >= 0 and x < cMAX_X and y >= 0 and y < cMAX_Y then
      data(23 downto 16) <= memory_in_L(x*3 + 3*(pImageHeight1-y-1)*GetWidth_L(header1));
      data(15 downto 8)  <= memory_in_L(x*3+1 + 3*(pImageHeight1-y-1)*GetWidth_L(header1));
      data(7 downto 0)   <= memory_in_L(x*3+2 + 3*(pImageHeight1-y-1)*GetWidth_L(header1));
    end if;
  end GetPixel_L;
  
  procedure GetGrayPixel_L(x : in integer; y : in integer; signal data : out std_logic_vector(7 downto 0)) is
  begin
    if x >= 0 and x < cMAX_X and y >= 0 and y < cMAX_Y then
		data(7 downto 0) <= memory_in_L(x*3+2 + 3*(pImageHeight1-y-1)*GetWidth_L(header1));
    end if;
  end GetGrayPixel_L;

  procedure SetPixel_L(x : in integer; y : in integer; signal data : in std_logic_vector(23 downto 0)) is
  begin
    if x >= 0 and x < cMAX_X and y >= 0 and y < cMAX_Y then
      memory_out_L(x*3+(pImageHeight1-y-1)*(GetWidth_L(header1)*3))   := data(23 downto 16);
      memory_out_L(x*3+1+(pImageHeight1-y-1)*(GetWidth_L(header1)*3)) := data(15 downto 8);
      memory_out_L(x*3+2+(pImageHeight1-y-1)*(GetWidth_L(header1)*3)) := data(7 downto 0);
    end if;
  end SetPixel_L;
 
  procedure SetGrayPixel_L(x : in integer; y : in integer; signal data : in std_logic_vector(7 downto 0)) is
  begin
    if x >= 0 and x < cMAX_X and y >= 0 and y < cMAX_Y then
			memory_out_L(x*3+(pImageHeight1-y-1)*(GetWidth_L(header1)*3))   := data(7 downto 0);
			memory_out_L(x*3+1+(pImageHeight1-y-1)*(GetWidth_L(header1)*3)) := data(7 downto 0);
			memory_out_L(x*3+2+(pImageHeight1-y-1)*(GetWidth_L(header1)*3)) := data(7 downto 0);
	    end if;
  end SetGrayPixel_L;


  -- larghezza immagine
  function GetWidth_L(header1 : in header_array) return integer is
  begin
    return conv_integer(header1(21) & header1(20) & header1(19) & header1(18));
  end function GetWidth_L;

  procedure GetWidth_L(signal width : out integer) is
  begin
    width <= pImageWidth1;
  end GetWidth_L;

  -- altezza immagine
  function GetHeigth_L(header1 : in header_array) return integer is
  begin
    return conv_integer(header1(25) & header1(24) & header1(23) & header1(22));
  end function GetHeigth_L;

  procedure GetHeigth_L(signal height : out integer) is
  begin
    height <= pImageHeight1;
  end GetHeigth_L;

	
	--Scrittura file
  procedure WriteFile_L(FileName : in string) is

    variable next_vector : character;
    variable index       : integer := 0;
    type     char_file is file of character;
    file write_file      : char_file open write_mode is FileName;

  begin
    report "Scrittura File...";
    report FileName;

    report "Scrittura Header";
    index := 0;
    for i in 0 to 53 loop
      next_vector := character'val(conv_integer(header1(index)));
      write(write_file, next_vector);
      index       := index + 1;
    end loop;


    report "Scrittura immagine";
    index := 0;
    while index < pImageSize1*3 loop
		next_vector := character'val(conv_integer(memory_out_L(index)));
		write(write_file, next_vector);
		index       := index + 1;
    end loop;

    report "Scrittura Okay";

  end WriteFile_L;

  
end gestioneBmp;