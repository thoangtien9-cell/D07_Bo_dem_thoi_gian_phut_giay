module d07_bcd_core(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tick_1hz,
    input  logic       enable,
    output logic [3:0] minute_tens,
    output logic [3:0] minute_units,
    output logic [3:0] second_tens,
    output logic [3:0] second_units
);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            minute_tens  <= 4'd0;
            minute_units <= 4'd0;
            second_tens  <= 4'd0;
            second_units <= 4'd0;
        end else if (enable && tick_1hz) begin
            if (second_units < 4'd9) begin
                second_units <= second_units + 4'd1;
            end else begin
                second_units <= 4'd0;
                if (second_tens < 4'd5) begin
                    second_tens <= second_tens + 4'd1;
                end else begin
                    second_tens <= 4'd0;
                    if (minute_units < 4'd9) begin
                        minute_units <= minute_units + 4'd1;
                    end else begin
                        minute_units <= 4'd0;
                        if (minute_tens < 4'd5)
                            minute_tens <= minute_tens + 4'd1;
                        else
                            minute_tens <= 4'd0;
                    end
                end
            end
        end
    end
endmodule
