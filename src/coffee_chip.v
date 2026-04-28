module coffee_chip (
    input wire clk,
    input wire reset,
    input wire sensor_out,
    input wire uart_rx,
    input wire s0_in,      // Config. física S0
    input wire s1_in,      // Config. física S1
    input wire cfg_sel,    // 0: Pines físicos, 1: UART

    output reg s0,
    output reg s1,
    output reg s2,
    output reg s3,
    output reg led_verde,  // INDICADOR: Inmaduro
    output reg led_azul,   // INDICADOR: Óptimo
    output reg led_rojo,   // INDICADOR: Pasado
    output reg debug_ready // Pulso de ciclo completado
);

    // Reducido para simulación (en implementación real usar 50_000_000)
    // Valor de producción: 50,000,000 ciclos = 1 segundo
    parameter WINDOW_MAX = 32'd50_000_000;

    //----------------------------------------
    // SINCRONIZADORES (Protección de Silicio)
    //----------------------------------------
    reg [1:0] s_sync, u_sync, s0_f, s1_f;
    reg s_prev;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            s_sync <= 2'b0; u_sync <= 2'b11; 
            s0_f <= 2'b0; s1_f <= 2'b0;
            s_prev <= 0;
        end else begin
            s_sync <= {s_sync[0], sensor_out};
            u_sync <= {u_sync[0], uart_rx};
            s0_f   <= {s0_f[0], s0_in};
            s1_f   <= {s1_f[0], s1_in};
            s_prev <= s_sync[1];
        end
    end

    //----------------------------------------
    // REGISTROS Y UART (Calibración)
    //----------------------------------------
    reg [15:0] r_min, r_max;
    reg [1:0]  s_uart;
    reg [1:0]  u_state;
    reg [7:0]  addr, d_high;
    wire [7:0] rx_data;
    wire rx_valid;

    uart_rx_core uart_inst (
        .clk(clk), 
        .reset(reset), 
        .rx(u_sync[1]), 
        .data(rx_data), 
        .valid(rx_valid)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            u_state <= 0; 
            r_min <= 16'd1000; 
            r_max <= 16'd8000; 
            s_uart <= 2'b10; // 2% de frecuencia por defecto
        end else if (rx_valid) begin
            case (u_state)
                0: if (rx_data == 8'hAA) u_state <= 1;
                1: begin addr <= rx_data; u_state <= 2; end
                2: begin d_high <= rx_data; u_state <= 3; end
                3: begin
                    case (addr)
                        8'h01: r_min <= {d_high, rx_data};
                        8'h02: r_max <= {d_high, rx_data};
                        8'h03: s_uart <= rx_data[1:0];
                    endcase
                    u_state <= 0;
                end
            endcase
        end
    end

    // Selección de Escala de Frecuencia
    always @(*) begin
        if (cfg_sel) {s0, s1} = s_uart;
        else         {s0, s1} = {s0_f[1], s1_f[1]};
    end

    //----------------------------------------
    // CONTEO DE FRECUENCIA POR VENTANA
    //----------------------------------------
    reg [23:0] edge_count, freq;
    reg [25:0] window_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            edge_count <= 0; 
            window_cnt <= 0; 
            freq <= 0;
        end else begin
            if (s_sync[1] && !s_prev) edge_count <= edge_count + 1;
            
            if (window_cnt < WINDOW_MAX) begin
                window_cnt <= window_cnt + 1;
            end else begin
                freq <= edge_count;
                edge_count <= 0;
                window_cnt <= 0;
            end
        end
    end

    //----------------------------------------
    // MÁQUINA DE ESTADOS (FSM) DE CLASIFICACIÓN
    //----------------------------------------
    reg [1:0] state;
    reg [23:0] r_val, g_val, b_val;
    localparam RED=0, GREEN=1, BLUE=2, EVAL=3;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= RED; 
            s2 <= 0; s3 <= 0;
            {led_verde, led_azul, led_rojo} <= 3'b000;
            debug_ready <= 0;
            r_val <= 0; g_val <= 0; b_val <= 0;
        end else if (window_cnt == WINDOW_MAX) begin
            case (state)
                RED: begin
                    r_val <= freq;
                    s2 <= 1; s3 <= 1; // Cambiar a filtro Verde
                    state <= GREEN;
                    debug_ready <= 0;
                end
                GREEN: begin
                    g_val <= freq;
                    s2 <= 0; s3 <= 1; // Cambiar a filtro Azul
                    state <= BLUE;
                end
                BLUE: begin
                    b_val <= freq;
                    state <= EVAL;
                end
                EVAL: begin
                    // Clasificación lógica
                    if (g_val > r_max) begin
                        {led_verde, led_azul, led_rojo} <= 3'b100; // INMADURO (Verde dominante)
                    end else if (r_val > r_min && g_val < r_min) begin
                        {led_verde, led_azul, led_rojo} <= 3'b010; // ÓPTIMO (Rojo presente, Verde bajo)
                    end else if (r_val < r_min) begin
                        {led_verde, led_azul, led_rojo} <= 3'b001; // PASADO (Poca reflexión total)
                    end else begin
                        {led_verde, led_azul, led_rojo} <= 3'b111; // DESCONOCIDO
                    end

                    debug_ready <= 1;
                    s2 <= 0; s3 <= 0; // Volver a filtro Rojo
                    state <= RED;
                end
            endcase
        end
    end
endmodule