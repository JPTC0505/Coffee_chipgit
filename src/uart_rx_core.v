module uart_rx_core (
    input wire clk,
    input wire reset,
    input wire rx,
    output reg [7:0] data,
    output reg valid
);
    // Para 50MHz y 9600 baudios: 50,000,000 / 9600 = 5208
    parameter CLK_PER_BIT = 5208;

    reg [12:0] clk_cnt; // Aumentado a 13 bits para soportar 5208
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shift;
    reg [1:0]  state;

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            valid <= 0;
            clk_cnt <= 0;
            bit_idx <= 0;
            rx_shift <= 0;
            data <= 0;
        end else begin
            valid <= 0;
            case (state)
                IDLE: begin
                    if (rx == 0) begin // Detección de Bit de Inicio
                        clk_cnt <= 0;
                        state <= START;
                    end
                end

                START: begin
                    // Muestreo a mitad del bit de inicio para asegurar estabilidad
                    if (clk_cnt == (CLK_PER_BIT-1)/2) begin
                        if (rx == 0) begin
                            clk_cnt <= 0;
                            state <= DATA;
                        end else state <= IDLE;
                    end else clk_cnt <= clk_cnt + 1;
                end

                DATA: begin
                    if (clk_cnt < CLK_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        rx_shift[bit_idx] <= rx;
                        if (bit_idx < 7) begin
                            bit_idx <= bit_idx + 1;
                        end else begin
                            bit_idx <= 0;
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_cnt < CLK_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        data <= rx_shift;
                        valid <= 1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule