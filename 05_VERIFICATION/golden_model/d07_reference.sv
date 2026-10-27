module d07_reference(
    input logic clk,
    input logic rst_n,
    input logic tick_1hz,
    input logic enable,
    output logic [5:0] minute,
    output logic [5:0] second
);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            minute <= 0;
            second <= 0;
        end else if (enable && tick_1hz) begin
            if (second < 59)
                second <= second + 1;
            else begin
                second <= 0;
                if (minute < 59)
                    minute <= minute + 1;
                else
                    minute <= 0;
            end
        end
    end
endmodule
