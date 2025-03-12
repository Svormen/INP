proc isim_script {} {

   add_divider "Signals of the Vigenere Interface"
   add_wave_label "" "CLK" /testbench/clk
   add_wave_label "" "RST" /testbench/rst
   add_wave_label "-radix ascii" "DATA" /testbench/tb_data
   add_wave_label "-radix ascii" "KEY" /testbench/tb_key
   add_wave_label "-radix ascii" "CODE" /testbench/tb_code

   add_divider "Vigenere Inner Signals"
   
   add_wave_label "" "fsm_mealy" /testbench/uut/fsm_mealy
   add_wave_label "" "sucasny_stav" /testbench/uut/sucasny_stav
   add_wave_label "" "dalsi_stav" /testbench/uut/dalsi_stav
   
   add_wave_label "-radix unsigned" "posun" /testbench/uut/posun
   add_wave_label "-radix unsigned" "posun_plus" /testbench/uut/posun_plus
   add_wave_label "-radix unsigned" "posun_minus" /testbench/uut/posun_minus

   
   

	 
	 
	
   run 8 ns
}
