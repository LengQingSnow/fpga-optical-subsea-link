`timescale 1ns/1ps
module tb_long_prbs;
    reg clk=0; always #2 clk=~clk;
    reg rst_n=0, capture_pulse=0, replay_enable=0;
    reg [63:0] live_data=64'h0123456789abcdef;
    reg live_valid=1, downstream_ready=1;
    wire live_ready,output_valid,reference_ready,replay_active;
    wire [63:0] output_data,reference_data;
    reg [5:0] reference_address=0;
    reg [30:0] model[0:3];
    reg [63:0] expected, prefix[0:63];
    reg [63:0] stalled;
    integer fd;
    ber_reference_replay dut(.*);
    task reset_model;
      begin
        model[0]=31'h13579bdf; model[1]=31'h2468ace1;
        model[2]=31'h5a6b7c1d; model[3]=31'h73c951a7;
      end
    endtask
    initial begin
      repeat(3) @(negedge clk); rst_n=1;
      #1; if(output_data!==live_data || !live_ready) $fatal(1,"Live passthrough failed");
      capture_pulse=1; replay_enable=1;
      @(negedge clk); capture_pulse=0;
      wait(reference_ready); @(negedge clk);
      reset_model(); fd=$fopen("long_prbs_words.hex","w");
      for(integer word=0;word<16448;word=word+1) begin
        if(word==16384) reset_model();
        for(integer sym=0;sym<16;sym=sym+1)
          for(integer lane=0;lane<4;lane=lane+1) begin
            expected[63-4*sym-lane]=model[lane][30];
            model[lane]={model[lane][29:0],model[lane][30]^model[lane][27]};
          end
        if(!output_valid || !replay_active || output_data!==expected)
          $fatal(1,"PRBS mismatch word=%0d got=%h expected=%h",word,output_data,expected);
        if(word<64) prefix[word]=output_data;
        if(word<16384) $fdisplay(fd,"%016h",output_data);
        if(word%37==5) begin
          downstream_ready=0; stalled=output_data;
          repeat(3) begin
            @(negedge clk);
            if(output_data!==stalled) $fatal(1,"Backpressure changed sequence");
          end
          downstream_ready=1;
        end
        @(negedge clk);
      end
      $fclose(fd);
      for(integer address=0;address<64;address=address+1) begin
        reference_address=address; #1;
        if(reference_data!==prefix[address]) $fatal(1,"Prefix mismatch %0d",address);
      end
      replay_enable=0; #1;
      if(output_data!==live_data) $fatal(1,"Disable did not restore live input");
      @(negedge clk); replay_enable=1; #1;
      if(output_data!==prefix[0]) $fatal(1,"Restart not at seed");
      $display("PASS LONG_PRBS full fragment, wrap, stall, reference and live bypass");
      $finish;
    end
endmodule
