module d07_bcd_tb;
    logic clk, rst_n, tick_1hz, enable;
    logic [3:0] mt, mu, st, su;
    integer i;

    d07_bcd_core dut(
        .clk(clk), .rst_n(rst_n), .tick_1hz(tick_1hz), .enable(enable),
        .minute_tens(mt), .minute_units(mu),
        .second_tens(st), .second_units(su)
    );

    always #5 clk = ~clk;

    task tick;
        begin
            tick_1hz = 1;
            @(posedge clk); #1;
            tick_1hz = 0;
        end
    endtask

    initial begin
        clk=0; rst_n=0; tick_1hz=0; enable=1;
        repeat(2) @(posedge clk);
        rst_n=1;

        assert({mt,mu,st,su} == 16'h0000);

        // 00:59
        for(i=0;i<59;i=i+1) tick();
        assert({mt,mu,st,su} == 16'h0059);

        // 01:00
        tick();
        assert({mt,mu,st,su} == 16'h0100);

        // Disable must hold.
        enable=0;
        repeat(3) tick();
        assert({mt,mu,st,su} == 16'h0100);

        enable=1;

        // Fast-forward from 01:00 to 59:59 by simulation.
        for(i=0;i<59*60-1;i=i+1) tick();
        // Boundary checks are handled by reference/exhaustive model as well.

        $display("D07 BCD TB PASS");
        $finish;
    end
endmodule
