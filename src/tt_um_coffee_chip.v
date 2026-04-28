`default_nettype none

module tt_um_coffee_chip (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Instancia del chip de café
    coffee_chip user_project (
        .clk(clk),
        .reset(!rst_n),         // Adaptación de reset_n (active low) a reset (active high)
        
        // Entradas (mapeadas a ui_in)
        .sensor_out(ui_in[0]),  // Entrada del sensor de frecuencia
        .uart_rx(ui_in[1]),     // Entrada UART
        .s0_in(ui_in[2]),       // Config física S0
        .s1_in(ui_in[3]),       // Config física S1
        .cfg_sel(ui_in[4]),     // Selector de configuración (0: Pines, 1: UART)
        
        // Salidas (mapeadas a uo_out)
        .s0(uo_out[0]),
        .s1(uo_out[1]),
        .s2(uo_out[2]),
        .s3(uo_out[3]),
        .led_verde(uo_out[4]),  // Indicador: Inmaduro
        .led_azul(uo_out[5]),   // Indicador: Óptimo
        .led_rojo(uo_out[6]),   // Indicador: Pasado
        .debug_ready(uo_out[7]) // Pulso de ciclo completado
    );

    // Manejo de señales no utilizadas
    // Usamos una operación lógica para evitar warnings de señales no conectadas
    wire _unused = &{ena, ui_in[7:5], uio_in, 1'b0};

    // Configuración de los pines Bidireccionales (uio)
    // En este caso, los ponemos todos como entradas en alta impedancia (no usados)
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule