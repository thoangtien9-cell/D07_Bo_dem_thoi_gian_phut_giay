module d07_binary_core(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tick_1hz,
    input  logic       enable,
    output logic [5:0] minute,
    output logic [5:0] second
);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            minute <= 6'd0;
            second <= 6'd0;
        end else if (enable && tick_1hz) begin
            if (second < 6'd59) begin
                second <= second + 6'd1;
            end else begin
                second <= 6'd0;
                if (minute < 6'd59)
                    minute <= minute + 6'd1;
                else
                    minute <= 6'd0;
            end
        end
    end
endmodule
