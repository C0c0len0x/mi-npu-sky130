module basic_npu #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ACC_WIDTH  = 20,
    parameter integer VECTOR_LEN = 4
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,
    input  wire [DATA_WIDTH-1:0]  data_in,
    input  wire [DATA_WIDTH-1:0]  weight_in,
    input  wire [DATA_WIDTH-1:0]  bias_in,
    input  wire                   valid_in,
    output reg  [DATA_WIDTH-1:0]  result_out,
    output reg                    valid_out,
    output reg                    busy
);

    localparam [1:0] IDLE     = 2'b00,
                     COMPUTE  = 2'b01,
                     ACTIVATE = 2'b10,
                     DONE     = 2'b11;

    reg [1:0] state;

    reg signed [ACC_WIDTH-1:0]  acc_reg;
    reg signed [DATA_WIDTH-1:0] bias_reg;
    integer                     counter;
    reg signed [ACC_WIDTH-1:0]  raw_result;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            acc_reg    <= {ACC_WIDTH{1'b0}};
            bias_reg   <= {DATA_WIDTH{1'b0}};
            counter    <= 0;
            result_out <= {DATA_WIDTH{1'b0}};
            valid_out  <= 1'b0;
            busy       <= 1'b0;
            raw_result <= {ACC_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    if (start) begin
                        bias_reg <= $signed(bias_in);
                        acc_reg  <= {ACC_WIDTH{1'b0}};
                        counter  <= 0;
                        busy     <= 1'b1;
                        state    <= COMPUTE;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                COMPUTE: begin
                    if (valid_in) begin
                        acc_reg <= acc_reg + ($signed(data_in) * $signed(weight_in));
                        if (counter == VECTOR_LEN - 1) begin
                            state <= ACTIVATE;
                        end else begin
                            counter <= counter + 1;
                        end
                    end
                end

                ACTIVATE: begin
                    raw_result <= acc_reg + $signed(bias_reg);
                    state      <= DONE;
                end

                DONE: begin
                    if (raw_result < 0) begin
                        result_out <= {DATA_WIDTH{1'b0}};
                    end else if (raw_result > 127) begin
                        result_out <= 8'h7F;
                    end else begin
                        result_out <= raw_result[DATA_WIDTH-1:0];
                    end
                    valid_out <= 1'b1;
                    busy      <= 1'b0;
                    state     <= IDLE;
                end
            endcase
        end
    end

endmodule
