library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;

entity test_tb is
	generic (runner_cfg : string);
end test_tb;

architecture rtl of test_tb is

	constant CLOCKSPEED : natural := 27;

	constant CLOCK_PER : time := (1000000/CLOCKSPEED) * 1 ps;

	signal i_LED		: std_logic_vector(5 downto 0);
	signal i_SER_TX 	: std_logic;
	signal i_BRD_CLK	: std_logic;
	signal i_SYS_RESn	: std_logic;

	signal i_O_psram_ck			: std_logic_vector(1 downto 0);
	signal i_O_psram_ck_n		: std_logic_vector(1 downto 0);
	signal i_IO_psram_rwds		: std_logic_vector(1 downto 0);
	signal i_IO_psram_dq		: std_logic_vector(15 downto 0);
	signal i_O_psram_reset_n	: std_logic_vector(1 downto 0);
	signal i_O_psram_cs_n		: std_logic_vector(1 downto 0);

	signal i_GSRI				: std_logic;

begin
	p_syscon_clk:process
	begin
		i_BRD_CLK <= '1';
		wait for CLOCK_PER / 2;
		i_BRD_CLK <= '0';
		wait for CLOCK_PER / 2;
	end process;


	p_main:process
	variable v_time:time;
	begin

		test_runner_setup(runner, runner_cfg);


		while test_suite loop

			if run("boop") then

				i_SYS_RESn <= '0';
				i_GSRI <= '0';
				wait for 69 us; -- must be > pll lock time
				i_SYS_RESn <= '1';
				i_GSRI <= '1';

				wait for 500 us;

			end if;


		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	e_dut:entity work.memory_test
	generic map (
		NO_PAUSE	=> 1
		)
	port map (

    sys_clk			=> i_BRD_CLK,
    sys_resetn		=> i_SYS_RESn,
    button			=> '1',

    led				=> i_LED,
    uart_txp		=> i_SER_TX,

    O_psram_ck		=> i_O_psram_ck,
    O_psram_ck_n	=> i_O_psram_ck_n,
    IO_psram_rwds	=> i_IO_psram_rwds,
    IO_psram_dq		=> i_IO_psram_dq,
    O_psram_reset_n	=> i_O_psram_reset_n,
    O_psram_cs_n	=> i_O_psram_cs_n
	);

	e_psram:entity work.s27kl0642
	port map (
    DQ7      => i_IO_psram_dq(7),
    DQ6      => i_IO_psram_dq(6),
    DQ5      => i_IO_psram_dq(5),
    DQ4      => i_IO_psram_dq(4),
    DQ3      => i_IO_psram_dq(3),
    DQ2      => i_IO_psram_dq(2),
    DQ1      => i_IO_psram_dq(1),
    DQ0      => i_IO_psram_dq(0),
    RWDS     => i_IO_psram_rwds(0),

    CSNeg    => i_O_psram_cs_n(0),
    CK       => i_O_psram_ck(0),
	CKn		 => i_O_psram_ck_n(0),
    RESETNeg => i_O_psram_reset_n(0)
    );

	GSR: entity work.GSR
	port map (
		GSRI => i_GSRI
		);

end rtl;
